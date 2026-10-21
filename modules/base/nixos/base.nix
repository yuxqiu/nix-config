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

      home-manager = {
        useUserPackages = true;
        backupFileExtension = "hm-bak";
      };

      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = [
            "root"
            "@"
          ];

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
