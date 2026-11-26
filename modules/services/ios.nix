{
  flake.modules.nixos.ios =
    { pkgs, ... }:
    {
      persistence.directories = [ "/var/lib/lockdown" ];
      services.usbmuxd.enable = true;

      programs.fuse.userAllowOther = true;

      environment.systemPackages = [
        pkgs.ifuse
        pkgs.libimobiledevice
      ];
    };
}
