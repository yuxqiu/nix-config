{ inputs, ... }:
{
  flake.modules.nixos.fprintd = {
    persistence.directories = [ "/var/lib/fprint" ];
    imports = [ inputs.fingerprint-lid-guard.nixosModules.default ];

    services.fprintd.enable = true;
  };
}
