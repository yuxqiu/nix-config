{
  flake.modules.nixos.printing = {
    services.printing.enable = true;
    # Otherwise CUPS enables printer discovery and pulls Avahi in at boot.
    services.printing.browsed.enable = false;
  };

  flake.modules.homeManager.printing =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.system-config-printer ];
    };
}
