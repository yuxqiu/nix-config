# VM test for the ephemeral-root module: / is a fresh tmpfs on every boot, paths
# listed in `persistence` survive a reboot and nothing else does, and the login
# password comes from a sops secret decrypted before users are created, with
# the key read through its kept directory's bind mount.
{
  pkgs,
  nixosEphemeralRoot,
  nixosBase,
  genericBase,
}:
let
  storage = "/disk";
  password = "correct horse battery staple";
  # Stands in for an older Home Manager generation: its links are left in kept
  # directories when the root is wiped, while Home Manager's own record of
  # that generation (under ~/.local/state) is not.
  oldGeneration = pkgs.runCommand "home-manager-files" { } ''
    mkdir -p $out/kept
    echo old > $out/kept/managed
    echo old > $out/kept/obsolete
  '';
  # A generation that has since been garbage-collected.
  goneGeneration = "/nix/store/00000000000000000000000000000000-home-manager-files";
in
pkgs.testers.runNixOSTest {
  name = "ephemeral-root";
  globalTimeout = 600;
  # nixos.base sets nixpkgs.config (allowUnfree).
  node.pkgsReadOnly = false;

  nodes.machine =
    { config, lib, ... }:
    {
      imports = [
        nixosEphemeralRoot
        genericBase
        # Home Manager and its file settings (force, overwriteBackup), and
        # the sops module.
        nixosBase
      ];

      # The VM's own root disk is replaced by the tmpfs; a second disk is the
      # persistent filesystem. qemu-vm overrides `fileSystems`, so the layout
      # goes through `virtualisation.fileSystems`.
      virtualisation.emptyDiskImages = [ 1024 ];
      virtualisation.fileSystems."/" = lib.mkForce {
        device = "none";
        fsType = "tmpfs";
        options = [ "mode=755" ];
      };
      virtualisation.fileSystems.${storage} = {
        device = "/dev/vdb";
        fsType = "ext4";
        autoFormat = true;
        neededForBoot = true;
      };
      persistence.storage = storage;

      # Outside the store, so the test can write it once the host key exists.
      sops.defaultSopsFile = "${storage}/test-secrets.yaml";
      sops.validateSopsFiles = false;
      sops.secrets.alice-password.neededForUsers = true;
      users.users.alice = {
        isNormalUser = true;
        hashedPasswordFile = config.sops.secrets.alice-password.path;
      };

      # Owned by a normal user: created by activation, then set by tmpfiles.
      # The second is declared like a directory whose program sets its own
      # mode: tmpfiles never changes it.
      persistence.directories = [
        {
          directory = "/var/lib/self-moded";
          mode = config.persistence.programSetsMode;
        }
        {
          directory = "/var/lib/kept";
          user = "alice";
          group = "users";
          mode = "0700";
        }
      ];
      home-manager.sharedModules = [ genericBase ];
      home-manager.users.alice = {
        home.stateVersion = "26.11";
        persistence.directories = [ "kept" ];
        # Not on the persistent filesystem at first boot.
        persistence.files = [ "kept-file" ];
        # A Home Manager file inside a kept directory, and one outside.
        home.file."kept/managed".text = "inside";
        home.file."kept/other".text = "other";
        # Replaced before the reboot by a foreign symlink and by a regular
        # file whose backup name is already taken.
        home.file."kept/forced-link".text = "declared";
        home.file."kept/forced-file".text = "declared";
        home.file.".config/managed".text = "outside";
      };
      # The same system with a file and a directory added to the keep list
      # after a program created them; the directory's parent is new too.
      specialisation.added.configuration.home-manager.users.alice.persistence = {
        files = [ "later-file" ];
        directories = [ "new-parent/later-dir" ];
      };

      # Keeps the stand-in older generation in the VM's store.
      environment.etc."old-home-manager-files".source = oldGeneration;

      environment.systemPackages = [
        pkgs.age
        pkgs.sops
        pkgs.mkpasswd
      ];
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("first boot: tmpfs root, host key on the persistent filesystem"):
        machine.succeed("findmnt -n -o FSTYPE / | grep -x tmpfs")
        machine.succeed("findmnt -n ${storage}")
        machine.succeed("test -s ${storage}/var/lib/sops-nix/key.txt")
        # Made through the bind mount, at the path sops-nix reads.
        machine.succeed("findmnt -n /var/lib/sops-nix")
        machine.succeed("cmp /var/lib/sops-nix/key.txt ${storage}/var/lib/sops-nix/key.txt")
        machine_id = machine.succeed("cat /etc/machine-id").strip()
        assert len(machine_id) == 32, machine_id
        machine.succeed(f"grep -x {machine_id} ${storage}/etc/machine-id")

    with subtest("UID allocation is kept, mounted before activation creates users"):
        machine.succeed("findmnt -n /var/lib/nixos")
        machine.succeed("grep -q '\"alice\"' ${storage}/var/lib/nixos/uid-map")
        uids = machine.succeed("getent passwd | cut -d: -f1,3 | sort")

    with subtest("a kept directory has its declared owner and mode on both sides"):
        machine.succeed("stat -c '%U %a' /var/lib/kept | grep -x 'alice 700'")
        machine.succeed("stat -c '%U %a' ${storage}/var/lib/kept | grep -x 'alice 700'")
        # systemd made it when mounting (DirectoryMode=, 0755), before
        # tmpfiles ran; a ":" mode does not change an existing directory.
        machine.succeed("stat -c '%a' /var/lib/self-moded | grep -x 755")
        # A program's own change stays (checked after the reboot).
        machine.succeed("chmod 750 /var/lib/self-moded")
        machine.succeed("chmod 750 /var/lib/kept")

    with subtest("a kept file missing from the storage is created there and mounted"):
        machine.succeed("findmnt -n /home/alice/kept-file")
        machine.succeed("su alice -c 'echo first > ~/kept-file'")
        machine.succeed("grep -x first ${storage}/home/alice/kept-file")

    with subtest("deliver the password hash, encrypted to the host key"):
        recipient = machine.succeed("age-keygen -y ${storage}/var/lib/sops-nix/key.txt").strip()
        hashed = machine.succeed("mkpasswd -m yescrypt '${password}'").strip()
        machine.succeed(f"printf 'alice-password: %s\\n' '{hashed}' > /tmp/plain.yaml")
        machine.succeed(f"sops --encrypt --age '{recipient}' --input-type yaml --output-type yaml /tmp/plain.yaml > ${storage}/test-secrets.yaml")

    with subtest("a path listed after a program wrote it is moved onto the storage on switch"):
        machine.succeed("su alice -c 'echo program > ~/later-file'")
        machine.succeed("su alice -c 'mkdir -p ~/new-parent/later-dir && echo program > ~/new-parent/later-dir/x'")
        machine.succeed("/run/current-system/specialisation/added/bin/switch-to-configuration test")
        machine.succeed("findmnt -n /home/alice/later-file")
        machine.succeed("findmnt -n /home/alice/new-parent/later-dir")
        machine.succeed("su alice -c 'grep -x program ~/later-file'")
        machine.succeed("su alice -c 'grep -x program ~/new-parent/later-dir/x'")
        machine.succeed("grep -x program ${storage}/home/alice/later-file")
        machine.succeed("grep -x program ${storage}/home/alice/new-parent/later-dir/x")
        # The new parent on the storage, and so the live one, stays alice's.
        machine.succeed("stat -c '%U %a' ${storage}/home/alice/new-parent | grep -x 'alice 755'")
        machine.succeed("stat -c '%U %a' /home/alice/new-parent | grep -x 'alice 755'")
        machine.succeed("su alice -c 'echo after > ~/new-parent/later-dir/y'")

    with subtest("leave state in kept and dropped places"):
        machine.succeed("echo kept > /var/lib/kept/marker")
        machine.succeed("echo dropped > /var/lib/dropped-marker")
        machine.succeed("su alice -c 'echo kept > ~/kept/marker'")
        machine.succeed("su alice -c 'mkdir -p ~/.config/autostart && echo x > ~/.config/autostart/planted.desktop'")
        machine.succeed("su alice -c 'echo dropped > ~/dropped-marker'")

    with subtest("leave links from older Home Manager generations in a kept directory"):
        machine.succeed("su alice -c 'ln -sfn ${oldGeneration}/kept/managed ~/kept/managed'")
        machine.succeed("su alice -c 'ln -sfn ${goneGeneration}/kept/other ~/kept/other'")
        machine.succeed("su alice -c 'ln -sfn ${oldGeneration}/kept/obsolete ~/kept/obsolete'")

    with subtest("plant files that would stop Home Manager from re-linking"):
        machine.succeed("su alice -c 'echo planted > ~/kept/planted-target && ln -sfn ~/kept/planted-target ~/kept/forced-link'")
        machine.succeed("su alice -c 'rm ~/kept/forced-file && echo planted > ~/kept/forced-file && echo older > ~/kept/forced-file.hm-bak'")

    machine.shutdown()
    machine.start()
    machine.wait_for_unit("multi-user.target")

    with subtest("second boot: kept state survives, everything else is gone"):
        machine.succeed("findmnt -n -o FSTYPE / | grep -x tmpfs")
        machine.succeed(f"grep -x {machine_id} /etc/machine-id")
        assert machine.succeed("getent passwd | cut -d: -f1,3 | sort") == uids, "UIDs changed"
        machine.succeed("stat -c '%a' /var/lib/self-moded | grep -x 750")
        # An enforced mode is set back.
        machine.succeed("stat -c '%a' /var/lib/kept | grep -x 700")
        machine.succeed("grep -x kept /var/lib/kept/marker")
        machine.fail("test -e /var/lib/dropped-marker")
        machine.succeed("su alice -c 'grep -x kept ~/kept/marker'")
        machine.fail("su alice -c 'test -e ~/.config/autostart/planted.desktop'")
        machine.fail("su alice -c 'test -e ~/dropped-marker'")

    with subtest("captured content and later writes are on the storage after reboot"):
        machine.succeed("grep -x program ${storage}/home/alice/later-file")
        machine.succeed("grep -x program ${storage}/home/alice/new-parent/later-dir/x")
        machine.succeed("grep -x after ${storage}/home/alice/new-parent/later-dir/y")

    with subtest("a kept file that exists on the storage is bind-mounted and kept"):
        machine.succeed("findmnt -n /home/alice/kept-file")
        machine.succeed("su alice -c 'echo kept > ~/kept-file'")
        machine.succeed("grep -x kept ${storage}/home/alice/kept-file")

    with subtest("the password comes from sops"):
        machine.succeed("test -s /run/secrets-for-users/alice-password")
        machine.succeed(f"grep -F 'alice:{hashed}:' /etc/shadow")

    with subtest("Home Manager activates again on the wiped root"):
        machine.wait_until_succeeds("systemctl show -p Result --value home-manager-alice.service | grep -x success")
        machine.succeed("su alice -c 'grep -x outside ~/.config/managed'")

    with subtest("Home Manager's declared files win over planted ones"):
        machine.succeed("su alice -c 'grep -x declared ~/kept/forced-link'")
        machine.succeed("su alice -c 'readlink ~/kept/forced-link' | grep -- '-home-manager-files/'")
        machine.succeed("su alice -c 'grep -x declared ~/kept/forced-file'")
        machine.succeed("su alice -c 'grep -x planted ~/kept/forced-file.hm-bak'")

    with subtest("links from older generations are replaced, with no Home Manager state"):
        # Resolving link into another generation: Home Manager treats it as its own.
        machine.succeed("su alice -c 'grep -x inside ~/kept/managed'")
        # Dangling link into a collected generation: not a collision either.
        machine.succeed("su alice -c 'grep -x other ~/kept/other'")
        # A file the new generation no longer manages stays behind: cleanup
        # needs the previous generation's file list, which was wiped.
        machine.succeed("su alice -c 'readlink ~/kept/obsolete' | grep -F '${oldGeneration}/kept/obsolete'")

    with subtest("activation makes no key on the wiped root when the key directory is not mounted"):
        machine.succeed("umount /var/lib/sops-nix")
        out = machine.fail("/run/current-system/activate 2>&1")
        assert "/var/lib/sops-nix is not mounted" in out, out
        machine.fail("test -e /var/lib/sops-nix/key.txt")
        machine.succeed("mount --bind ${storage}/var/lib/sops-nix /var/lib/sops-nix")
  '';
}
