# VM test of the two ways a machine joins, both with the host's age key made
# and granted before the machine first runs the host's config, so it decrypts
# from the start: a remote install with real nixos-anywhere (disko + install
# with the key injected by --extra-files, then booting the installed disk),
# and a machine that already runs NixOS bootstrapped with os-bootstrap, then
# switching to the flake.
{
  pkgs,
  nixosSops,
  disko,
}:
let
  sshKeys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;
  keyFile = "/var/lib/sops-nix/key.txt";

  fakePassCli = pkgs.writeShellScriptBin "pass-cli" ''
    case "$1" in
      info) [ -e /tmp/pass-session ] ;;
      login) touch /tmp/pass-session ;;
      logout) rm /tmp/pass-session ;;
      item) cat /root/admin.txt ;;
      *) exit 2 ;;
    esac
  '';
  sops-tools = pkgs.callPackage ../packages/sops-tools.nix { proton-pass-cli = fakePassCli; };
  os-bootstrap = pkgs.callPackage ../packages/os-bootstrap.nix { inherit sops-tools; };

  # os-bootstrap asks the flake (`nix eval`) for the host's key path,
  # persistence storage, the storage's device and mount options, and secrets
  # needed for users; the test has no flake, so this answers from files the
  # test writes in /root/fake-eval.
  fakeNix = pkgs.writeShellScriptBin "nix" ''
    case "$*" in
      *sops.age.keyFile*) cat /root/fake-eval/key-file ;;
      *persistence.storage*) cat /root/fake-eval/storage ;;
      *getAttr*.device*) cat /root/fake-eval/device ;;
      *getAttr*.options*) cat /root/fake-eval/options ;;
      *neededForUsers*) cat /root/fake-eval/user-secrets ;;
      *) echo "fake nix: unexpected: $*" >&2; exit 1 ;;
    esac
  '';

  # What every host here runs: the base module, one secret from a file the
  # test delivers (outside the store, as a redeploy would), root over SSH.
  hostConfig = {
    imports = [ nixosSops ];
    services.openssh.enable = true;
    users.users.root.openssh.authorizedKeys.keys = [ sshKeys.snakeOilEd25519PublicKey ];
    sops.defaultSopsFile = "/etc/test-secrets/host.yaml";
    sops.validateSopsFiles = false;
    sops.secrets.greeting = { };
  };

  # Installed by nixos-anywhere onto the target's second disk, then booted
  # from that disk alone.
  installed = pkgs.nixos (
    { modulesPath, ... }:
    {
      imports = [
        hostConfig
        disko
        (modulesPath + "/testing/test-instrumentation.nix")
        (modulesPath + "/profiles/qemu-guest.nix")
      ];
      networking.hostName = "newhost";
      documentation.enable = false;
      disko.devices.disk.main = {
        device = "/dev/vdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    }
  );

  writeGreeting = pkgs.writeShellScript "write-greeting" ''
    echo "greeting: hello" > "$1"
  '';
in
pkgs.testers.runNixOSTest {
  name = "sops-pq-install";
  # A passing run takes about 53 s of VM time; anything stuck fails here.
  globalTimeout = 180;
  defaults.documentation.enable = false;

  nodes.admin = {
    environment.systemPackages = [
      sops-tools
      pkgs.nixos-anywhere
      pkgs.age
      pkgs.sops
      pkgs.git
      pkgs.yq-go
    ];
    environment.etc."install/disko".source = installed.config.system.build.diskoScript;
    environment.etc."install/system".source = installed.config.system.build.toplevel;
    programs.ssh.extraConfig = ''
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
    '';
  };

  # A running machine with an empty second disk to install onto. It is not
  # nixos-anywhere's installer image, so the disko script brings its own tools.
  nodes.target = {
    services.openssh.enable = true;
    users.users.root.openssh.authorizedKeys.keys = [ sshKeys.snakeOilEd25519PublicKey ];
    virtualisation.emptyDiskImages = [ 4096 ];
    virtualisation.memorySize = 1536;
  };

  # A machine that already runs NixOS; `adopted` is the flake's config for it.
  nodes.fresh = {
    # A second disk for a persistent filesystem laid out before bootstrapping.
    virtualisation.emptyDiskImages = [ 512 ];
    environment.systemPackages = [
      pkgs.btrfs-progs
      os-bootstrap
      sops-tools
      pkgs.age
      pkgs.sops
      pkgs.git
      pkgs.yq-go
    ];
    services.openssh.enable = true;
    users.users.root.openssh.authorizedKeys.keys = [ sshKeys.snakeOilEd25519PublicKey ];
    specialisation.adopted.configuration = hostConfig;
  };

  testScript = ''
    def setup_admin():
        admin.succeed("install -d -m 700 /root/.ssh && install -m 600 ${sshKeys.snakeOilEd25519PrivateKey} /root/.ssh/id_ed25519")
        admin.succeed("age-keygen -pq -o /root/admin.txt")
        admin.succeed(
            "mkdir -p /root/repo/secrets && cd /root/repo && git init -q && "
            "printf 'keys:\\n  - &yuxqiu %s\\ncreation_rules:\\n"
            "  - path_regex: secrets/newhost\\\\.yaml$\\n    key_groups:\\n      - age:\\n          - *yuxqiu\\n"
            "  - path_regex: secrets/fresh\\\\.yaml$\\n    key_groups:\\n      - age:\\n          - *yuxqiu\\n'"
            " \"$(age-keygen -y /root/admin.txt)\" > .sops.yaml"
        )

    def new_secrets(name):
        admin.succeed(f"cd /root/repo && SOPS_EDITOR=${writeGreeting} sops-update admin secrets/{name}.yaml")

    def assert_own_key(machine):
        machine.succeed("test \"$(stat -c %a:%U ${keyFile})\" = 600:root")
        machine.succeed("grep -q '^AGE-SECRET-KEY-PQ-1' ${keyFile}")
        machine.succeed("grep -q '^age1pq1' ${keyFile}.pub")

    start_all()
    setup_admin()

    with subtest("remote: the key is made on admin, granted, and injected by nixos-anywhere"):
        target.wait_for_unit("sshd.service")
        admin.wait_until_succeeds("ssh root@target true")
        new_secrets("newhost")
        # Made on a tmpfs, as os-install does; never on admin's disk.
        admin.succeed("install -d -m 700 /dev/shm/inject && install -d -m 755 /dev/shm/inject/root$(dirname ${keyFile}) /dev/shm/inject/root/etc/test-secrets")
        admin.succeed("(umask 077 && age-keygen -pq -o /dev/shm/inject/root${keyFile}) && age-keygen -y /dev/shm/inject/root${keyFile} > /dev/shm/inject/root${keyFile}.pub")
        injected_sum = admin.succeed("sha256sum < /dev/shm/inject/root${keyFile}")
        admin.succeed("cd /root/repo && sops-update-key add admin /dev/shm/inject/root${keyFile} secrets/newhost.yaml")
        # This test's hosts read secrets from a runtime path; in the flake they
        # come from the store, so only the key would be injected.
        admin.succeed("cp /root/repo/secrets/newhost.yaml /dev/shm/inject/root/etc/test-secrets/host.yaml")
        admin.succeed(
            "nixos-anywhere -i /root/.ssh/id_ed25519 --phases disko,install "
            "--no-substitute-on-destination --extra-files /dev/shm/inject/root "
            "--store-paths /etc/install/disko /etc/install/system root@target >&2"
        )
        target.shutdown()

    newhost = create_machine(
        start_command=" ".join([
            "${pkgs.qemu_test}/bin/qemu-kvm", "-cpu", "max", "-m", "1024",
            "-virtfs", "local,path=/nix/store,security_model=none,mount_tag=nix-store",
            "-drive", f"file={target.state_dir}/empty0.qcow2,id=drive1,if=none,index=1,werror=report",
            "-device", "virtio-blk-pci,drive=drive1",
        ]),
        name="newhost",
    )
    driver.machines.append(newhost)
    # The test driver's cleanup doesn't stop a VM started this way, and the
    # build waits for it, so stop it here whatever happens.
    try:
        with subtest("remote: the installed disk boots with the injected key and decrypts at once"):
            newhost.start()
            newhost.wait_for_unit("multi-user.target")
            assert newhost.succeed("hostname").strip() == "newhost"
            assert_own_key(newhost)
            assert newhost.succeed("sha256sum < ${keyFile}") == injected_sum, "not the injected key"
            # No key was generated anywhere: it existed before activation.
            newhost.succeed("! journalctl -b -o cat | grep -q 'Public key: age1pq1'")
            assert newhost.succeed("cat /run/secrets/greeting").strip() == "hello"

    finally:
        newhost.crash()

    def fresh_repo():
        admin.copy_from_machine("/root/admin.txt")
        fresh.copy_from_host(str(admin.out_dir / "admin.txt"), "/root/admin.txt")
        fresh.succeed(
            "mkdir -p /root/flake/profiles/hosts/fresh/secrets && cd /root/flake && git init -q && "
            "printf 'keys:\\n  - &yuxqiu %s\\ncreation_rules:\\n"
            "  - path_regex: profiles/hosts/fresh/secrets/fresh\\\\.yaml$\\n    key_groups:\\n      - age:\\n          - *yuxqiu\\n'"
            " \"$(age-keygen -y /root/admin.txt)\" > .sops.yaml && "
            "SOPS_EDITOR=${writeGreeting} sops-update admin profiles/hosts/fresh/secrets/fresh.yaml"
        )
        fresh.succeed("mkdir -p /root/fake-eval /root/fakebin && ln -s ${fakeNix}/bin/nix /root/fakebin/nix")
        fresh.succeed("printf %s ${keyFile} > /root/fake-eval/key-file && truncate -s0 /root/fake-eval/storage")
        fresh.succeed("printf alice-password > /root/fake-eval/user-secrets")
        fresh.succeed("mkdir -p /etc/nixos && echo '{ }' > /etc/nixos/hardware-configuration.nix")

    def bootstrap(expect_ok):
        cmd = "cd /root/flake && PATH=/root/fakebin:$PATH os-bootstrap fresh 2>&1"
        return fresh.succeed(cmd) if expect_ok else fresh.fail(cmd)

    with subtest("local: os-bootstrap makes and grants the key, copies the hardware config, stops on a missing secret"):
        fresh.wait_for_unit("multi-user.target")
        fresh.fail("test -e ${keyFile}")
        fresh_repo()
        out = bootstrap(False)
        assert "Made the host key" in out and "Granted the key" in out, out
        assert "alice-password" in out and "Ready" not in out, out
        assert_own_key(fresh)
        fresh.succeed("test -f /root/flake/profiles/hosts/fresh/_hardware-configuration.nix")
        pub = fresh.succeed("cat ${keyFile}.pub").strip()
        assert pub in fresh.succeed("cat /root/flake/.sops.yaml"), "key not granted"
        fresh.succeed("! test -e /tmp/pass-session")

    with subtest("local: rerun after adding the secret; each step is skipped once done"):
        key_sum = fresh.succeed("sha256sum < ${keyFile}")
        fresh.succeed(
            "cd /root/flake && SOPS_AGE_KEY_FILE=/root/admin.txt "
            "sops set profiles/hosts/fresh/secrets/fresh.yaml '[\"alice-password\"]' '\"$y$hash\"'"
        )
        out = bootstrap(True)
        assert "Host key exists" in out and "already has access" in out and "exists" in out, out
        assert "nixos-rebuild boot --flake .#fresh" in out, out
        assert fresh.succeed("sha256sum < ${keyFile}") == key_sum, "key replaced on rerun"

    def impermanent(storage, device, options=""):
        fresh.succeed(f"printf %s {storage} > /root/fake-eval/storage && printf %s {storage}${keyFile} > /root/fake-eval/key-file")
        fresh.succeed(f"printf %s {device} > /root/fake-eval/device && printf %s '{options}' > /root/fake-eval/options")

    def place_key(base):
        # The key already granted, where os-bootstrap should look; so a run
        # reports the path it chose without granting a new key.
        fresh.succeed(f"install -d -m 755 {base}$(dirname ${keyFile}) && cp -p ${keyFile} ${keyFile}.pub {base}$(dirname ${keyFile})/")

    with subtest("local: converted in place, the running root becomes the persistent filesystem"):
        impermanent("/disk", fresh.succeed("findmnt -n -o SOURCE /").strip())
        out = bootstrap(True)
        assert "mounted at /, so the key goes at ${keyFile}" in out and "Host key exists: ${keyFile}" in out, out

    with subtest("local: a persistent subvolume already mounted at the storage path"):
        fresh.succeed("mkfs.btrfs -q /dev/vdb && mkdir -p /mnt/top && mount /dev/vdb /mnt/top && btrfs -q subvolume create /mnt/top/@persist")
        fresh.succeed("mkdir -p /persist && mount -o subvol=@persist /dev/vdb /persist")
        impermanent("/persist", "/dev/vdb", "subvol=@persist,noatime")
        place_key("/persist")
        out = bootstrap(True)
        # The top level (also /dev/vdb, at /mnt/top) is not the subvolume.
        assert "mounted at /persist, so the key goes at /persist${keyFile}" in out, out
        assert "Host key exists: /persist${keyFile}" in out and "already has access" in out, out

    with subtest("local: the persistent subvolume mounted somewhere else"):
        fresh.succeed("umount /persist && mkdir -p /mnt/elsewhere && mount -o subvol=@persist /dev/vdb /mnt/elsewhere")
        out = bootstrap(True)
        assert "mounted at /mnt/elsewhere, so the key goes at /mnt/elsewhere${keyFile}" in out, out
        assert "Host key exists: /mnt/elsewhere${keyFile}" in out, out

    with subtest("local: a subvolume spelled with a leading slash, and the top level as subvol=/"):
        impermanent("/persist", "/dev/vdb", "subvol=/@persist")
        out = bootstrap(True)
        assert "mounted at /mnt/elsewhere, so the key goes at /mnt/elsewhere${keyFile}" in out, out
        # The btrfs top level, as a desktop converted in place mounts it.
        impermanent("/persist", "/dev/vdb", "subvol=/,noatime")
        place_key("/mnt/top")
        out = bootstrap(True)
        assert "mounted at /mnt/top, so the key goes at /mnt/top${keyFile}" in out, out
        # Back to the subvolume, which the next subtest unmounts.
        impermanent("/persist", "/dev/vdb", "subvol=@persist,noatime")

    with subtest("local: an unmounted persistent filesystem stops before making a key"):
        fresh.succeed("umount /mnt/elsewhere")
        sops_before = fresh.succeed("sha256sum < /root/flake/.sops.yaml")
        out = bootstrap(False)
        assert "is not mounted" in out and "Made the host key" not in out, out
        assert fresh.succeed("sha256sum < /root/flake/.sops.yaml") == sops_before, ".sops.yaml changed"
        fresh.succeed("umount /mnt/top")
        fresh.succeed("truncate -s0 /root/fake-eval/storage && printf %s ${keyFile} > /root/fake-eval/key-file")

    with subtest("local: the first switch to the host's config decrypts at once"):
        fresh.succeed("mkdir -p /etc/test-secrets && cp /root/flake/profiles/hosts/fresh/secrets/fresh.yaml /etc/test-secrets/host.yaml")
        fresh.succeed("/run/current-system/specialisation/adopted/bin/switch-to-configuration switch")
        assert fresh.succeed("cat /run/secrets/greeting").strip() == "hello"
  '';
}
