{
  flake.modules.nixos.cedrus =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      retention = [
        "--keep-last 5"
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
      iosMount = "/tmp/restic-ios";
      chatMount = "/tmp/restic-ios-chat";
      rootOwnedSecret = {
        mode = "0400";
        owner = config.users.users.root.name;
        inherit (config.users.users.root) group;
      };
    in
    {
      sops.secrets = {
        "rclone.conf" = rootOwnedSecret;
        "restic-home-password" = rootOwnedSecret;
        "restic-ios-password" = rootOwnedSecret;
      };

      services.restic.backups = {
        home = {
          repository = "rclone:koofr:yuxqiu-laptop";
          rcloneConfigFile = config.sops.secrets."rclone.conf".path;
          passwordFile = config.sops.secrets."restic-home-password".path;
          initialize = true;
          paths = [ "${config.users.users.yuxqiu.home}/Documents" ];
          exclude = [
            "*.pyc"
            "**/.idea"
            "**/target/"
            "**/__pycache__/"
            "**/.pytest_cache"
            "*.class"
            "node_modules"
          ];
          pruneOpts = retention;
          runCheck = true;
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
          };
        };

        ios = {
          repository = "rclone:koofr:iphone-15-pro";
          rcloneConfigFile = config.sops.secrets."rclone.conf".path;
          passwordFile = config.sops.secrets."restic-ios-password".path;
          initialize = true;
          paths = [
            "${iosMount}/DCIM"
            "${chatMount}/ChatBackup"
          ];
          extraBackupArgs = [ "--ignore-inode" ];
          pruneOpts = retention;
          runCheck = true;
          timerConfig = null;
          backupPrepareCommand = ''
            set -e
            mkdir -p "${iosMount}" "${chatMount}"
            idevicepair pair
            ifuse "${iosMount}" -o allow_root
            ifuse --documents com.readdle.ReaddleDocsIPad "${chatMount}" -o allow_root
          '';
          backupCleanupCommand = ''
            fusermount -u "${iosMount}" 2>/dev/null || true
            fusermount -u "${chatMount}" 2>/dev/null || true
          '';
        };
      };

      systemd.services = {
        "restic-backups-home".path = lib.mkAfter [ pkgs.rclone ];
        "restic-backups-ios".path = lib.mkAfter [
          pkgs.rclone
          pkgs.fuse
          pkgs.ifuse
          pkgs.libimobiledevice
        ];
      };

      environment.systemPackages = [
        pkgs.rclone
        pkgs.restic
      ];
    };
}
