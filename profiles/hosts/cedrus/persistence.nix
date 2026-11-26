{
  flake.modules.nixos.cedrus =
    { config, ... }:
    {
      # The ext4 filesystem that was the root before / moved to tmpfs. It holds
      # /nix and everything kept, at the same paths as before, so a generation
      # from before the conversion still boots from it as its root.
      fileSystems."/disk" = {
        device = "/dev/disk/by-uuid/142862d6-6393-4cf8-92e1-1e61a9cea266";
        fsType = "ext4";
        neededForBoot = true;
      };
      # Shutdown logs "Failed unmounting /nix/store"; harmless. NixOS's systemd
      # patch exempts /nix and /nix/store from unmounting, but not /disk: it
      # was mounted in the initrd, so systemd sees no x-initrd.mount in its
      # runtime options and gives it Conflicts=umount.target. Stopping it
      # propagates through Requires= (/nix/store -> /nix -> /disk), and the
      # busy store fails to unmount. systemd-shutdown then remounts what is
      # left read-only, so the filesystem is closed cleanly (no ext4 journal
      # recovery at the next boot). Separate partitions for /nix and the kept
      # paths would avoid it.
      fileSystems."/nix" = {
        device = "/disk/nix";
        fsType = "none";
        options = [ "bind" ];
        depends = [ "/disk" ];
        neededForBoot = true;
      };
      persistence.storage = "/disk";

      # Bind mounts of kept directories exist only after activation, when
      # secrets are installed, so the key is read from the filesystem itself.
      sops.age.keyFile = "/disk/var/lib/sops-nix/key.txt";

      # Users are immutable; the login password is a hash in sops, decrypted
      # before users are created.
      sops.secrets.yuxqiu-password.neededForUsers = true;
      users.users.yuxqiu.hashedPasswordFile = config.sops.secrets.yuxqiu-password.path;

      # Gurobi's license, in one of its default locations. Kept as a directory:
      # a kept file in the home is a bind mount without x-gvfs-hide, which
      # file managers list as a mount.
      persistence.directories = [ "/opt/gurobi" ];
    };

  flake.modules.homeManager.cedrus = {
    persistence.directories = [
      "Documents"
      "Desktop"
      "Downloads"
      "Pictures"
      "Videos"
      "Games"
      ".dotfiles"
      ".local/share/Trash"
    ];
  };
}
