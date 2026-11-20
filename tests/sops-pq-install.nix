# VM test of the two ways a machine joins: a remote install with real
# nixos-anywhere (disko + install, then booting the installed disk), and a
# machine that already runs NixOS switching to the flake. In both, the host
# makes its own age key on activation and decrypts once given access.
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

    with subtest("remote: nixos-anywhere installs the host onto a disk"):
        target.wait_for_unit("sshd.service")
        admin.wait_until_succeeds("ssh root@target true")
        admin.succeed(
            "nixos-anywhere -i /root/.ssh/id_ed25519 --phases disko,install "
            "--no-substitute-on-destination "
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
        with subtest("remote: the installed disk boots with the key made during install"):
            newhost.start()
            newhost.wait_for_unit("multi-user.target")
            assert newhost.succeed("hostname").strip() == "newhost"
            assert_own_key(newhost)
            # nixos-install already ran activation in the new root (nixos-enter),
            # so the key predates this boot, and sops-nix found it.
            newhost.succeed("! journalctl -b -o cat | grep -q 'Public key: age1pq1'")
            newhost.succeed("! journalctl -b -o cat | grep -q 'cannot read keyfile'")
            newhost.fail("test -e /run/secrets/greeting")

        with subtest("remote: given access, the installed host decrypts"):
            # The installed VM has no network to admin; its public key and the
            # re-encrypted file travel through the test driver instead of SSH.
            new_secrets("newhost")
            pub = newhost.succeed("cat ${keyFile}.pub").strip()
            admin.succeed(f"echo {pub} > /root/newhost-key.pub")
            admin.succeed("cd /root/repo && sops-update-key add admin /root/newhost-key secrets/newhost.yaml")
            admin.copy_from_machine("/root/repo/secrets/newhost.yaml")
            newhost.succeed("mkdir -p /etc/test-secrets")
            # create_machine VMs have no shared folder, so this goes over the shell.
            newhost.copy_from_host_via_shell(str(admin.out_dir / "newhost.yaml"), "/etc/test-secrets/host.yaml")
            newhost.succeed("/run/current-system/activate")
            assert newhost.succeed("cat /run/secrets/greeting").strip() == "hello"

    finally:
        newhost.crash()

    with subtest("local: an existing NixOS switches to the flake and makes its key"):
        fresh.wait_for_unit("multi-user.target")
        fresh.fail("test -e ${keyFile}")
        fresh.execute("/run/current-system/specialisation/adopted/bin/switch-to-configuration switch")
        assert_own_key(fresh)
        fresh.fail("test -e /run/secrets/greeting")

    with subtest("local: given access over SSH, it decrypts after the next switch"):
        new_secrets("fresh")
        admin.succeed("cd /root/repo && sops-update-key add admin root@fresh:${keyFile} secrets/fresh.yaml")
        admin.succeed("ssh root@fresh mkdir -p /etc/test-secrets")
        admin.succeed("scp /root/repo/secrets/fresh.yaml root@fresh:/etc/test-secrets/host.yaml")
        fresh.succeed("/run/current-system/bin/switch-to-configuration switch")
        assert fresh.succeed("cat /run/secrets/greeting").strip() == "hello"
  '';
}
