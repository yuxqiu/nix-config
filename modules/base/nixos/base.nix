{ inputs, ... }:

{
  flake.modules.nixos.base =
    {
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];

      # Home Manager's declared files always win. Without force, activation
      # stops on a file it cannot back up: a foreign symlink, or a regular
      # file whose <file>.hm-bak already exists. Any process running as the
      # user can plant either, so a replaced file inside a kept directory
      # would survive the boot-time re-link. With force the collision check is
      # skipped; a foreign regular file is still moved to <file>.hm-bak
      # (replacing an older backup) before the link is placed. mkForce, since
      # Home Manager's xdg.*File options copy their own force (default false)
      # into home.file and a weaker default would lose to that copy.
      home-manager = {
        useUserPackages = true;
        backupFileExtension = "hm-bak";
        overwriteBackup = true;
        sharedModules = [
          {
            options.home.file = lib.mkOption {
              type = lib.types.attrsOf (lib.types.submodule { force = lib.mkForce true; });
            };
          }
        ];
      };

      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = [ "root" ];

          auto-optimise-store = true;
        };

        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };

        extraOptions = ''
          accept-flake-config = true
          http-connections = 50
          keep-derivations = true
          keep-outputs = true
          min-free = ${toString (1024 * 1024 * 1024)}
          max-free = ${toString (5 * 1024 * 1024 * 1024)}
        '';
      };

      nixpkgs.config.allowUnfree = true;

      boot.tmp.cleanOnBoot = true;

      i18n.defaultLocale = "en_US.UTF-8";

      environment.defaultPackages = lib.mkForce [ ];

      environment.systemPackages = with pkgs; [
        bottom
        dig
        # `os-switch <host> <target>` (nh) diffs the new system against the
        # target's current one, which needs dix >= 3.0.0 on the target.
        dix
        duf
        fastfetch
        jq
        less
        mtr
        openssl
        rsync
        screen
        sqlite
        strace
        tree
        wget
        which
      ];

      programs.git.enable = true;
      programs.zsh.enable = true;

      environment.etc."nixos/configuration.nix".text = ''
        # This file intentionally left minimal.
        # The real system config is managed by the nix-config flake.
        # To rebuild: nixos cedrus
        { ... }:
        {
          imports = [ ./hardware-configuration.nix ];
        }
      '';
    };
}
