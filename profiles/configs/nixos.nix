{
  lib,
  config,
  inputs,
  ...
}:

{
  options.configurations.nixos = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          system = lib.mkOption {
            type = lib.types.str;
            example = "aarch64-linux";
            description = "Target system/platform for this NixOS configuration";
          };

          stateVersion = lib.mkOption {
            type = lib.types.str;
            description = "NixOS system state version";
          };

          homeManager = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  username = lib.mkOption {
                    type = lib.types.str;
                    description = "Username for the home-manager user";
                  };

                  stateVersion = lib.mkOption {
                    type = lib.types.str;
                    description = "Home Manager state version";
                  };

                  modules = lib.mkOption {
                    type = lib.types.listOf lib.types.deferredModule;
                    default = [ ];
                    description = "List of home-manager modules to include for this NixOS configuration";
                  };
                };
              }
            );
            default = null;
            description = "Home Manager configuration for this host's primary user, or null for a headless/root-only host";
          };

          modules = lib.mkOption {
            type = lib.types.listOf lib.types.deferredModule;
            default = [ ];
            description = "List of modules for this NixOS configuration";
          };
        };
      }
    );

    default = { };
  };

  config.flake.nixosConfigurations =
    let
      hardwareConfig = name: ../hosts + "/${name}/_hardware-configuration.nix";
    in
    lib.mapAttrs (
      name: cfg:
      let
        mv = inputs.multiverse.lib.mkMultiverse {
          inherit (cfg) system;
          config.allowUnfree = true;
        };
      in
      inputs.nixpkgs.lib.nixosSystem {
        inherit (cfg) system;
        specialArgs = {
          inherit inputs mv;
        };
        modules =
          cfg.modules
          ++ [
            { system.stateVersion = cfg.stateVersion; }
          ]
          # Generated hardware config (nixos-generate-config, written by
          # os-install). It is a NixOS module, not a flake-parts one, so its name
          # starts with "_" for import-tree to skip it and it is imported here.
          ++ lib.optional (builtins.pathExists (hardwareConfig name)) (hardwareConfig name)
          ++ (lib.optional (cfg.homeManager != null) {
            home-manager.users.${cfg.homeManager.username} = {
              imports = cfg.homeManager.modules;
              home.stateVersion = cfg.homeManager.stateVersion;
            };
            home-manager.extraSpecialArgs = { inherit mv; };
            home-manager.sharedModules = [
              {
                nixpkgs.config = config.nixpkgs.config;
                nixpkgs.overlays = config.nixpkgs.overlays;
              }
            ];
          });
      }
    ) config.configurations.nixos;
}
