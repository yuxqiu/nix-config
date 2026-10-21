{
  lib,
  config,
  inputs,
  ...
}:
{
  options.nixpkgs = {
    config = {
      allowUnfreePredicate = lib.mkOption {
        type = lib.types.functionTo lib.types.bool;
        default = _: false;
      };
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
    config.allowUnfreePredicate = pkg: true;
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
