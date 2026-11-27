{ inputs, ... }:
{
  # Root on tmpfs, wiped at every boot, so state survives only where a module
  # or the host lists it in `persistence`; files dropped anywhere else (shell
  # startup, autostart, user units) are gone after a reboot. The host mounts
  # its persistent filesystem and sets `persistence.storage` to it; every
  # listed path is bind-mounted from the same path under that mount by
  # nix-community/preservation: systemd mount units, and systemd-tmpfiles
  # rules that set each kept path's declared owner and mode (default root or
  # the user, 0755 for directories and 0644 for files) at every boot.
  flake.modules.nixos.ephemeral-root =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.persistence) storage;
      preserved = config.preservation.preserveAt.${storage};
      # Without it file managers list every kept path as a mount.
      mountOptions = [ "x-gvfs-hide" ];

      # Every kept path, system and Home Manager, as an absolute live path.
      # Preservation adds the missing parents of per-user paths to the users'
      # lists as `_intermediate` entries; those are not kept.
      keptPaths =
        let
          users = lib.attrValues preserved.users;
          kept = lib.filter (entry: entry.how != "_intermediate");
        in
        map (d: d.directory) (kept (preserved.directories ++ lib.concatMap (u: u.directories) users))
        ++ map (f: f.file) (kept (preserved.files ++ lib.concatMap (u: u.files) users));

      # Moves a path listed for the first time onto the storage before it is
      # mounted, so content a program wrote before the path was listed is
      # kept. Without this, an empty storage directory or file (made by
      # systemd or tmpfiles) is mounted over the live content, which is lost
      # at reboot. Skipped: paths already on the storage, missing live, links
      # (Home Manager's) and mounts.
      captureNewlyKept = pkgs.writeShellApplication {
        name = "persistence-capture";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.util-linux
        ];
        text = ''
          storage=${lib.escapeShellArg storage}
          # Unmounted, the storage path is a directory on the tmpfs: a move
          # would land on the wiped root.
          if ! mountpoint -q "$storage"; then
            echo "persistence-capture: $storage is not mounted, nothing moved" >&2
            exit 1
          fi
          status=0
          for live in "$@"; do
            stored="$storage$live"
            if [ -e "$stored" ] || [ -L "$stored" ] || [ ! -e "$live" ] || [ -L "$live" ] || mountpoint -q "$live"; then
              continue
            fi
            # New parents on the storage take the live ones' owner and mode.
            parent=""
            IFS=/ read -ra parts <<<"$(dirname "''${live#/}")"
            for part in "''${parts[@]}"; do
              [ "$part" = . ] && continue
              parent="$parent/$part"
              if [ ! -d "$storage$parent" ]; then
                mkdir "$storage$parent"
                chown --reference="$parent" "$storage$parent"
                chmod --reference="$parent" "$storage$parent"
              fi
            done
            # Copied under a staging name and renamed into place, so a copy
            # that fails partway never sits at the final name, where the next
            # run would take it as already kept and mount it over the live
            # data. The live copy is removed only after the rename.
            stage="$stored.persistence-capture"
            if [ -e "$stage" ] || [ -L "$stage" ]; then
              echo "persistence-capture: $stage is left from a failed run; remove it, then switch again" >&2
              status=1
              continue
            fi
            if cp -a -- "$live" "$stage" && mv -T -- "$stage" "$stored" && rm -rf --one-file-system -- "$live"; then
              echo "persistence-capture: moved $live to the persistent storage"
            else
              echo "persistence-capture: could not move $live to $stored" >&2
              status=1
            fi
          done
          exit "$status"
        '';
      };
    in
    {
      imports = [ inputs.preservation.nixosModules.preservation ];

      options.persistence.keptPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        readOnly = true;
        default = keptPaths;
        description = "Every kept path, system and Home Manager, as an absolute live path (read by capture and by os-install --keep-state).";
      };

      options.persistence.storage = lib.mkOption {
        type = lib.types.str;
        example = "/disk";
        description = "Mount point of the host's persistent filesystem; listed paths are bind-mounted from under it.";
      };

      config = {
        # Needed by every host: UID/GID allocation, systemd state (timers,
        # random seed), the journal, and the machine identity.
        persistence.directories = [
          # UID/GID allocation (uid-map, gid-map), read when activation
          # creates users, which runs in the initrd.
          {
            directory = "/var/lib/nixos";
            mode = "0755";
            inInitrd = true;
          }
          {
            directory = "/var/lib/systemd";
            mode = "0755";
          }
          {
            directory = "/var/log";
            mode = "0755";
          }
        ];
        persistence.files = [
          # Read by systemd before stage 2, so mounted in the initrd. Empty
          # on a fresh storage (tmpfiles creates it); systemd then generates
          # an id and writes it through the bind mount.
          {
            file = "/etc/machine-id";
            mode = "0444";
            inInitrd = true;
          }
        ];
        # That bind mount is writable, so systemd writes a newly generated id
        # straight to it. The commit unit saves an id systemd kept on a tmpfs
        # over a read-only file; here it has nothing to save and fails ("not
        # on a temporary file system").
        systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

        fileSystems."/" = lib.mkForce {
          device = "none";
          fsType = "tmpfs";
          options = [
            "defaults"
            "mode=755"
          ];
        };

        preservation.enable = true;
        preservation.preserveAt.${storage} = {
          commonMountOptions = mountOptions;
          inherit (config.persistence) directories files;
          # Home Manager configs list paths relative to the home directory.
          users = lib.mapAttrs (_: home: {
            commonMountOptions = mountOptions;
            inherit (home.persistence) directories files;
          }) config.home-manager.users;
        };

        # A zone set with timedatectl lives in /etc/localtime, which is rebuilt
        # every boot. With no declared zone, keep the link on the persistent
        # filesystem: saved at shutdown (while it is still mounted), restored
        # at boot only if /etc/localtime is missing, so a config switch never
        # undoes a zone set during the session.
        system.activationScripts.restore-localtime = lib.mkIf (config.time.timeZone == null) {
          deps = [ "etc" ];
          text = ''
            if [ ! -e /etc/localtime ] && [ ! -L /etc/localtime ] && [ -L ${storage}/etc/localtime ]; then
              ln -s "$(readlink ${storage}/etc/localtime)" /etc/localtime
            fi
          '';
        };
        systemd.services.save-localtime = lib.mkIf (config.time.timeZone == null) {
          description = "Keep the timezone set with timedatectl across reboots";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ storage ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStop = pkgs.writeShellScript "save-localtime" ''
              if [ -L /etc/localtime ]; then
                mkdir -p ${storage}/etc
                cp -P --remove-destination /etc/localtime ${storage}/etc/localtime
              fi
            '';
          };
        };

        # Activation runs before a switch starts new mount units and before
        # systemd-tmpfiles creates empty storage paths for new entries.
        system.activationScripts.persistence-capture = {
          deps = [
            "users"
            "groups"
          ];
          text = "${lib.getExe captureNewlyKept} ${lib.escapeShellArgs config.persistence.keptPaths}";
        };

        # sudo records who has seen its first-use lecture in /var/db/sudo,
        # which is not kept, so the lecture would show after every boot.
        security.sudo.extraConfig = "Defaults lecture=never";

        # /etc is rebuilt every boot, so users and passwords come only from the
        # config; a password set with `passwd` would not survive.
        users.mutableUsers = false;

        # With immutable users, initialPassword/password become the actual
        # password and override hashedPassword (NixOS users-groups.nix
        # precedence), in plain text in the store.
        assertions = lib.concatLists (
          lib.mapAttrsToList (name: user: [
            {
              assertion = !user.isNormalUser || user.hashedPasswordFile != null || user.hashedPassword != null;
              message = "ephemeral-root.nix: users are immutable, so ${name} needs hashedPasswordFile (e.g. a sops secret with neededForUsers = true) or cannot log in.";
            }
            {
              assertion = user.initialPassword == null && user.password == null;
              message = "ephemeral-root.nix: users are immutable, so ${name}'s initialPassword/password would be the real password, in plain text; use hashedPasswordFile.";
            }
          ]) config.users.users
        );
      };
    };
}
