{
  lib,
  config,
  self,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks =
        lib.mapAttrs' (
          name: _:
          lib.nameValuePair "nixos-${name}" (
            pkgs.runCommand "check-nixos-${name}" { } ''
              test -e ${config.flake.nixosConfigurations.${name}.config.system.build.toplevel}
              touch "$out"
            ''
          )
        ) (lib.filterAttrs (_: cfg: cfg.system == system) config.configurations.nixos)
        // {
          formatting = pkgs.runCommand "check-formatting" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            cd ${self}
            find . -type f -name '*.nix' -print0 | xargs -0 nixfmt --check
            touch "$out"
          '';

          deadnix = pkgs.runCommand "check-deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
            cd ${self}
            deadnix --fail --no-lambda-arg --no-lambda-pattern-names .
            touch "$out"
          '';

          statix = pkgs.runCommand "check-statix" { nativeBuildInputs = [ pkgs.statix ]; } ''
            cd ${self}
            statix check .
            touch "$out"
          '';
        };

      formatter = pkgs.nixfmt-tree;
    };
}
