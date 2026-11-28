{
  lib,
  config,
  inputs,
  ...
}:
{
  # The nixpkgs config and overlays of every package set this flake builds:
  # perSystem `pkgs` (flake packages, apps, checks), the NixOS systems, their
  # Home Manager users, and the multiverse.
  options.nixpkgs = {
    config = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      description = "nixpkgs `config` for every package set this flake builds.";
    };
    overlays = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      description = "nixpkgs overlays for every package set this flake builds.";
    };
  };

  config.nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      inputs.nix-vscode-extensions.overlays.default
    ];
  };

  config.perSystem =
    { system, ... }:
    {
      _module.args = {
        pkgs = import inputs.nixpkgs {
          inherit system;
          inherit (config.nixpkgs) config overlays;
        };
        # Every version of every nixpkgs package, as the `mv` special argument
        # of NixOS and Home Manager modules (e.g. `mv.versions.<pkg>`).
        mv = inputs.multiverse.lib.mkMultiverse {
          inherit system;
          inherit (config.nixpkgs) config overlays;
        };
      };
    };
}
