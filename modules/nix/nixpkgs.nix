{
  lib,
  config,
  inputs,
  ...
}:
{
  options.nixpkgs = {
    config = {
      allowUnfree = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
    overlays = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
    };
  };

  config.nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      inputs.nix-vscode-extensions.overlays.default
    ];
  };

  config = {
    perSystem =
      { system, ... }:
      {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          inherit (config.nixpkgs) config overlays;
        };
      };
  };
}
