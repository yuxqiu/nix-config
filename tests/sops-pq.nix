# VM test for post-quantum sops: the host makes its own age key at first
# activation, and sops-update/sops-update-key/os-install give it access to its
# secrets. Proton Pass and nixos-anywhere are replaced by fakes that record
# how they were called, so the test runs offline.
{
  pkgs,
  nixosSops,
}:
let
  sshKeys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;
  keyFile = "/var/lib/sops-nix/key.txt";

  # Proton Pass with one item: the admin key at /root/admin.txt. Logs every
  # call to /tmp/pass-log; a session exists while /tmp/pass-session does.
  fakePassCli = pkgs.writeShellScriptBin "pass-cli" ''
    echo "$*" >> /tmp/pass-log
    case "$1" in
      info) [ -e /tmp/pass-session ] ;;
      login) touch /tmp/pass-session ;;
      logout) rm /tmp/pass-session ;;
      item)
        [ -e /tmp/pass-session ] || { echo "not logged in" >&2; exit 1; }
        [ "$*" = "item view --vault-name sops --item-title age-admin --field key" ] || exit 2
        cat /root/admin.txt
        ;;
      *) exit 2 ;;
    esac
  '';

  # Records its arguments, keeps a copy of the --extra-files tree (deleted by
  # os-install when it exits) and, like the real one, writes the hardware
  # config. Fails after recording when /tmp/fail-install exists.
  fakeNixosAnywhere = pkgs.writeShellScriptBin "nixos-anywhere" ''
    printf '%s\n' "$@" > /tmp/nixos-anywhere-args
    rm -rf /tmp/extra-files
    while [ $# -gt 0 ]; do
      case "$1" in
        --generate-hardware-config) echo "{ }" > "$3" ;;
        --extra-files) cp -a "$2" /tmp/extra-files ;;
      esac
      shift
    done
    [ ! -e /tmp/fail-install ]
  '';
  # os-install takes `nix` from PATH: it asks for the host's key path and
  # evaluates the host.
  fakeNix = pkgs.writeShellScriptBin "nix" ''
    printf '%s\n' "$*" >> /tmp/nix-args
    case "$*" in
      *sops.age.keyFile*) printf '%s' ${keyFile} ;;
    esac
  '';

  sops-tools = pkgs.callPackage ../packages/sops-tools.nix { proton-pass-cli = fakePassCli; };
  os-install = pkgs.callPackage ../packages/os-install.nix {
    nixos-anywhere = fakeNixosAnywhere;
    inherit sops-tools;
  };

  # SOPS_EDITOR for creating a secrets file: replaces its content.
  writeGreeting = pkgs.writeShellScript "write-greeting" ''
    echo "greeting: hello" > "$1"
  '';
in
pkgs.testers.runNixOSTest {
  name = "sops-pq";
  # Passing runs take about 32 s of VM time; a hang fails with a traceback
  # instead of running for the default hour.
  globalTimeout = 120;

  nodes.host = {
    imports = [ nixosSops ];
    services.openssh.enable = true;
    users.users.root.openssh.authorizedKeys.keys = [ sshKeys.snakeOilEd25519PublicKey ];
    # Outside the store, so the test can deliver re-encrypted files at run
    # time the way a redeploy would.
    sops.defaultSopsFile = "/etc/test-secrets/host.yaml";
    sops.validateSopsFiles = false;
    sops.secrets.greeting = { };
    environment.systemPackages = [ pkgs.age ];
  };

  nodes.admin = {
    environment.systemPackages = [
      sops-tools
      os-install
      pkgs.age
      pkgs.sops
      pkgs.git
      pkgs.yq-go
    ];
    programs.ssh.extraConfig = ''
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
    '';
  };

  testScript = ''
    import json

    hostkey = "root@host:${keyFile}"

    def sops_yaml():
        return admin.succeed("cat /root/repo/.sops.yaml")

    def rule_aliases(i):
        return admin.succeed(f"yq '.creation_rules[{i}].key_groups[0].age[] | alias' /root/repo/.sops.yaml").split()

    def file_recipients(f):
        out = admin.succeed(f"yq -o json '.sops.age' /root/repo/{f}")
        return [r["recipient"] for r in json.loads(out)]

    def decrypts(key, f):
        return admin.execute(f"SOPS_AGE_KEY_FILE={key} sops -d /root/repo/{f}")[0] == 0

    def deliver_and_activate():
        admin.succeed("scp /root/repo/secrets/host.yaml root@host:/etc/test-secrets/host.yaml")
        host.succeed("/run/current-system/activate")
        return host.succeed("cat /run/secrets/greeting").strip()

    def pass_clean():
        # Every run that used the admin key logged out again, and its private
        # session directory is gone.
        admin.succeed("! test -e /tmp/pass-session")
        admin.succeed("test -z \"$(ls /dev/shm | grep sops-pass)\"")

    start_all()

    with subtest("host makes its own post-quantum key at first boot"):
        host.wait_for_unit("multi-user.target")
        host.succeed("mkdir -p /etc/test-secrets")
        host.succeed("test \"$(stat -c %a:%U ${keyFile})\" = 600:root")
        host.succeed("grep -q '^AGE-SECRET-KEY-PQ-1' ${keyFile}")
        host.succeed("test \"$(stat -c %a ${keyFile}.pub)\" = 644")
        host.succeed("test \"$(cat ${keyFile}.pub)\" = \"$(age-keygen -y ${keyFile})\"")
        host.succeed("grep -q '^age1pq1' ${keyFile}.pub")
        host.succeed("runuser -u nobody -- cat ${keyFile}.pub")
        host.fail("runuser -u nobody -- cat ${keyFile}")
        # At first boot the key exists before sops-nix starts installing secrets.
        host.succeed(
            "made=$(journalctl -b -o cat | grep -n -m1 'Public key: age1pq1' | cut -d: -f1); "
            "setup=$(journalctl -b -o cat | grep -n -m1 'setting up secrets' | cut -d: -f1); "
            "[ -n \"$made\" ] && [ -n \"$setup\" ] && [ \"$made\" -lt \"$setup\" ]"
        )

    with subtest("missing secrets don't stop the host; the key survives reboot and reactivation"):
        host.fail("test -e /run/secrets/greeting")
        host.wait_for_unit("sshd.service")
        before = host.succeed("sha256sum ${keyFile}")
        host.execute("/run/current-system/activate")
        host.shutdown()
        host.start()
        host.wait_for_unit("multi-user.target")
        assert host.succeed("sha256sum ${keyFile}") == before, "key changed"

    with subtest("admin repo: files created with the admin key from Proton Pass"):
        admin.succeed("install -d -m 700 /root/.ssh && install -m 600 ${sshKeys.snakeOilEd25519PrivateKey} /root/.ssh/id_ed25519")
        admin.succeed("age-keygen -pq -o /root/admin.txt")
        admin.succeed(
            "mkdir -p /root/repo/secrets && cd /root/repo && git init -q && "
            "printf 'keys:\\n  - &yuxqiu %s\\ncreation_rules:\\n"
            "  - path_regex: secrets/host\\\\.yaml$\\n    key_groups:\\n      - age:\\n          - *yuxqiu\\n"
            "  - path_regex: secrets/other\\\\.yaml$\\n    key_groups:\\n      - age:\\n          - *yuxqiu\\n'"
            " \"$(age-keygen -y /root/admin.txt)\" > .sops.yaml"
        )
        for f in ["host", "other"]:
            admin.succeed(f"cd /root/repo && SOPS_EDITOR=${writeGreeting} sops-update admin secrets/{f}.yaml")
        assert decrypts("/root/admin.txt", "secrets/host.yaml")
        pass_clean()
        admin.succeed("grep -qx login /tmp/pass-log && grep -qx logout /tmp/pass-log")

    with subtest("add: only the rule matching the file gets the host key; data key rotated"):
        other_before = admin.succeed("sha256sum /root/repo/secrets/other.yaml")
        mac_before = admin.succeed("yq '.sops.mac' /root/repo/secrets/host.yaml")
        admin.succeed(f"cd /root/repo && sops-update-key add admin {hostkey} secrets/host.yaml")
        assert rule_aliases(0) == ["yuxqiu", "host"], rule_aliases(0)
        assert rule_aliases(1) == ["yuxqiu"], rule_aliases(1)
        host_pub = host.succeed("cat ${keyFile}.pub").strip()
        assert sorted(file_recipients("secrets/host.yaml")) == sorted(
            [admin.succeed("age-keygen -y /root/admin.txt").strip(), host_pub]
        )
        assert admin.succeed("yq '.sops.mac' /root/repo/secrets/host.yaml") != mac_before, "data key not rotated"
        assert admin.succeed("sha256sum /root/repo/secrets/other.yaml") == other_before, "other file changed"
        pass_clean()

    with subtest("the host decrypts after redeploy"):
        assert deliver_and_activate() == "hello"

    with subtest("refusals leave .sops.yaml unchanged"):
        before = sops_yaml()
        admin.succeed("age-keygen -o /root/classic.txt && age-keygen -pq -o /root/stranger.txt")
        admin.succeed("touch /root/repo/secrets/none.yaml")
        for cmd, why in [
            (f"add admin {hostkey} secrets/host.yaml", "already in the rule"),
            ("add admin /root/classic.txt secrets/host.yaml", "Not a post-quantum age key"),
            ("add admin admin secrets/none.yaml", "No .sops.yaml rule matches"),
            ("remove admin admin secrets/other.yaml", "last key"),
            ("add admin /root/stranger.txt secrets/host.yaml", "already named &host"),
                ("add /root/stranger.txt /root/stranger.txt secrets/other.yaml", "restored"),
        ]:
            out = admin.fail(f"cd /root/repo && sops-update-key {cmd} 2>&1")
            assert why in out, f"{cmd}: {out}"
            assert sops_yaml() == before, f".sops.yaml changed by: {cmd}"
        pass_clean()

    with subtest("remote decrypt key: remove the admin key using the host's key"):
        admin.succeed(f"cd /root/repo && sops-update-key remove {hostkey} admin secrets/host.yaml")
        assert rule_aliases(0) == ["host"], rule_aliases(0)
        assert "&yuxqiu" in sops_yaml(), "admin key dropped though other.yaml still uses it"
        assert not decrypts("/root/admin.txt", "secrets/host.yaml")
        assert deliver_and_activate() == "hello"

    with subtest("add the admin key back, reusing its existing name"):
        admin.succeed(f"cd /root/repo && sops-update-key add {hostkey} admin secrets/host.yaml")
        assert rule_aliases(0) == ["host", "yuxqiu"], rule_aliases(0)
        assert decrypts("/root/admin.txt", "secrets/host.yaml")
        pass_clean()

    with subtest("a key can remove itself"):
        admin.succeed("age-keygen -pq -o /root/temp.txt && cp /root/repo/secrets/host.yaml /root/repo/secrets/temp.yaml")
        admin.succeed(
            "cd /root/repo && yq -i '.creation_rules += [{\"path_regex\": \"secrets/temp\\\\.yaml$\", "
            "\"key_groups\": [{\"age\": [\"_\"]}]}] | .creation_rules[-1].key_groups[0].age[0] alias = \"yuxqiu\"' .sops.yaml"
        )
        admin.succeed("cd /root/repo && sops-update-key add admin /root/temp.txt secrets/temp.yaml")
        assert decrypts("/root/temp.txt", "secrets/temp.yaml")
        admin.succeed("cd /root/repo && sops-update-key remove /root/temp.txt /root/temp.txt secrets/temp.yaml")
        assert not decrypts("/root/temp.txt", "secrets/temp.yaml")
        assert decrypts("/root/admin.txt", "secrets/temp.yaml")
        assert "&temp" not in sops_yaml(), "unused key left in keys"

    with subtest("os-install: checks before wiping"):
        admin.succeed("mkdir -p /root/flake/profiles/hosts/newhost /root/fakebin && ln -s ${fakeNix}/bin/nix /root/fakebin/nix")
        out = admin.fail("cd /root/flake && os-install newhost root@10.0.0.9 2>&1")
        assert "secrets/newhost.yaml" in out, out
        admin.fail("test -e /tmp/nixos-anywhere-args")
        admin.succeed(
            "cd /root/flake && "
            "printf 'keys:\\n  - &yuxqiu %s\\ncreation_rules:\\n"
            "  - path_regex: profiles/hosts/newhost/secrets/newhost\\\\.yaml$\\n    key_groups:\\n      - age:\\n          - *yuxqiu\\n'"
            " \"$(age-keygen -y /root/admin.txt)\" > .sops.yaml && mkdir -p profiles/hosts/newhost/secrets && "
            "SOPS_EDITOR=${writeGreeting} sops-update admin profiles/hosts/newhost/secrets/newhost.yaml"
        )

    def flake_state():
        return admin.succeed("cd /root/flake && sha256sum .sops.yaml profiles/hosts/newhost/secrets/newhost.yaml")

    def os_install(args):
        return f"cd /root/flake && PATH=/root/fakebin:$PATH os-install newhost root@10.0.0.9 {args}"

    with subtest("os-install: a failed install restores .sops.yaml and the secrets"):
        before = flake_state()
        admin.succeed("touch /tmp/fail-install")
        out = admin.fail(os_install("2>&1"))
        assert "restored .sops.yaml" in out, out
        # The fake wrote the hardware config before failing, like the real
        # one would; the next install should generate it again.
        admin.succeed("rm /tmp/fail-install /root/flake/profiles/hosts/newhost/_hardware-configuration.nix")
        assert flake_state() == before, "flake files changed by a failed install"
        admin.succeed("test -z \"$(ls /dev/shm | grep os-install)\"")
        pass_clean()

    with subtest("os-install: the host key is made here, granted, and injected"):
        admin.succeed("echo '10.0.0.9 ${sshKeys.snakeOilEd25519PublicKey}' > /root/.ssh/known_hosts")
        out = admin.succeed(os_install("--build-on remote"))
        args = admin.succeed("cat /tmp/nixos-anywhere-args").split()
        assert args[:3] == [
            "--generate-hardware-config", "nixos-generate-config",
            "profiles/hosts/newhost/_hardware-configuration.nix",
        ], args
        assert args[3] == "--extra-files" and args[4].startswith("/dev/shm/os-install."), args
        assert args[5:] == ["--flake", ".#newhost", "--target-host", "root@10.0.0.9", "--build-on", "remote"], args
        # The injected tree holds the key at the host's sops.age.keyFile.
        injected = "/tmp/extra-files${keyFile}"
        admin.succeed(f"test \"$(stat -c %a {injected})\" = 600")
        admin.succeed(f"grep -q '^AGE-SECRET-KEY-PQ-1' {injected}")
        pub = admin.succeed(f"age-keygen -y {injected}").strip()
        assert pub in admin.succeed("cat /root/flake/.sops.yaml"), "key not granted"
        admin.succeed(f"cd /root/flake && SOPS_AGE_KEY_FILE={injected} sops -d profiles/hosts/newhost/secrets/newhost.yaml | grep -q hello")
        # The local copy is gone; the install output says what to commit.
        admin.succeed("test -z \"$(ls /dev/shm | grep os-install)\"")
        assert "Commit .sops.yaml" in out, out
        admin.fail("grep -q 10.0.0.9 /root/.ssh/known_hosts")
        pass_clean()

    with subtest("os-install: a reinstall keeps the hardware config, evaluates the host first and replaces its key"):
        first = pub
        admin.succeed(os_install(""))
        args = admin.succeed("cat /tmp/nixos-anywhere-args").split()
        second = admin.succeed(f"age-keygen -y {injected}").strip()
        assert second != first, "reinstall reused the old key"
        yaml = admin.succeed("cat /root/flake/.sops.yaml")
        assert second in yaml and first not in yaml, yaml
        admin.succeed(f"cd /root/flake && SOPS_AGE_KEY_FILE={injected} sops -d profiles/hosts/newhost/secrets/newhost.yaml | grep -q hello")
        assert args[0] == "--extra-files" and args[2:] == ["--flake", ".#newhost", "--target-host", "root@10.0.0.9"], args
        admin.succeed("grep -q 'nixosConfigurations.newhost.config.system.build.toplevel.drvPath' /tmp/nix-args")
  '';
}
