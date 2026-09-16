{
  lib,
  config,
  self,
  inputs,
  ...
}:
let
  flakeRef = "${self.outPath}";
  mkPkgs =
    system:
    import inputs.nixpkgs {
      inherit system;
      inherit (config.nixpkgs) config overlays;
    };

  mkHmConfigsForSystem =
    system: lib.filterAttrs (_: cfg: cfg.system == system) config.configurations.homeManager;
  mkNixosConfigsForSystem =
    system: lib.filterAttrs (_: cfg: cfg.system == system) config.configurations.nixos;
in
{
  config.flake = {
    apps = lib.genAttrs config.systems (
      system:
      let
        hmConfigs = mkHmConfigsForSystem system;
        nixosConfigs = mkNixosConfigsForSystem system;
        pkgs = mkPkgs system;

        hmApps = lib.mapAttrs' (
          name: _:
          let
            appName = "hm-${name}";
            script = pkgs.writeShellApplication {
              name = appName;
              runtimeInputs = [ pkgs.nix ];
              text = ''
                exec nix run ${inputs.home-manager} -- switch --flake "${flakeRef}#${name}"
              '';
            };
          in
          lib.nameValuePair appName {
            type = "app";
            program = "${script}/bin/${appName}";
          }
        ) hmConfigs;

        nixosApps = lib.mapAttrs' (
          name: _:
          let
            appName = "nixos-${name}";
            script = pkgs.writeShellApplication {
              name = appName;
              runtimeInputs = [ pkgs.nix ];
              text = ''
                exec nixos-rebuild switch --flake "${flakeRef}#${name}" --use-remote-sudo "$@"
              '';
            };
          in
          lib.nameValuePair appName {
            type = "app";
            program = "${script}/bin/${appName}";
          }
        ) nixosConfigs;
      in
      hmApps // nixosApps
    );

    checks = lib.genAttrs config.systems (
      system:
      let
        hmConfigs = mkHmConfigsForSystem system;
        nixosConfigs = mkNixosConfigsForSystem system;
        pkgs = mkPkgs system;

        hmChecks = lib.mapAttrs' (
          name: _:
          lib.nameValuePair "home-${name}" (
            pkgs.runCommand "check-home-${name}" { } ''
              test -e ${config.flake.homeConfigurations.${name}.activationPackage}
              touch "$out"
            ''
          )
        ) hmConfigs;

        nixosChecks = lib.mapAttrs' (
          name: _:
          lib.nameValuePair "nixos-${name}" (
            pkgs.runCommand "check-nixos-${name}" { } ''
              test -e ${config.flake.nixosConfigurations.${name}.config.system.build.toplevel}
              touch "$out"
            ''
          )
        ) nixosConfigs;
      in
      hmChecks // nixosChecks
    );

    formatter = lib.genAttrs config.systems (system: (mkPkgs system).nixfmt-tree);
  };
}
