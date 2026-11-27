{
  flake.modules.nixos.ios =
    { config, pkgs, ... }:
    {
      # Pairing records. usbmuxd chowns the directory to the user it runs as
      # and sets its mode (02775) at every start (src/main.c).
      persistence.directories = [
        {
          directory = "/var/lib/lockdown";
          inherit (config.services.usbmuxd) user group;
          mode = config.persistence.programSetsMode;
        }
      ];
      services.usbmuxd.enable = true;

      programs.fuse.userAllowOther = true;

      environment.systemPackages = [
        pkgs.ifuse
        pkgs.libimobiledevice
      ];
    };
}
