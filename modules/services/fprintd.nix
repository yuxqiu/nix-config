{ inputs, ... }:
{
  flake.modules.nixos.fprintd = {
    imports = [ inputs.fingerprint-lid-guard.nixosModules.default ];

    services.fprintd.enable = true;
  };
}
