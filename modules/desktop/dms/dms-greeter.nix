{
  inputs,
  ...
}:
{
  flake.modules.nixos.dms = { lib, ... }: {
    imports = [
      inputs.dank-greeter.nixosModules.default
    ];

    programs.dms-greeter = {
      enable = true;
      compositor.name = "niri";
    };

    # nixpkgs' greetd is Type=idle: it starts only once the boot job queue is
    # empty (or after 5 s), which keeps boot messages off a text greeter's
    # console. This greeter draws its own screen, so it gains nothing from
    # that, while any slow start job at boot (network-online.target, units
    # waiting for a connection) would hold back the login screen.
    systemd.services.greetd.serviceConfig.Type = lib.mkForce "exec";
  };
}
