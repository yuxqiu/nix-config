# Every packages/<name>.nix as flake package <name>, the one place they are
# built. Modules use them as `inputs.self.packages.${system}.<name>`; from a
# checkout, `nix build .#<name>` or `nix shell .#<name>`.
{ lib, inputs, ... }:
let
  packageNames = map (lib.removeSuffix ".nix") (
    lib.attrNames (
      lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".nix" file) (
        builtins.readDir ../packages
      )
    )
  );
  packageFile = name: ../packages + "/${name}.nix";
in
{
  perSystem =
    { pkgs, system, ... }:
    let
      # One scope, so a package takes another by naming it as an argument
      # (dms-brightness takes niri-focused-output, os-install takes sops-tools).
      scope = lib.makeScope pkgs.newScope (
        self: lib.genAttrs packageNames (name: self.callPackage (packageFile name) { })
      );
    in
    {
      packages = lib.genAttrs packageNames (name: scope.${name}) // {
        # Packaged by its own flake; listed here so every consumer names it
        # the same way as the packages above.
        nix-update-git = inputs.nix-update-git.packages.${system}.default;
      };
    };
}
