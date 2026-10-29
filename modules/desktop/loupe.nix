{
  flake.modules.homeManager.loupe =
    { lib, pkgs, ... }:
    {
      home.packages = with pkgs; [
        loupe
      ];

      xdg.mimeApps.defaultApplications = {
        "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
        "image/png" = [ "org.gnome.Loupe.desktop" ];
        "image/gif" = [ "org.gnome.Loupe.desktop" ];
        "image/webp" = [ "org.gnome.Loupe.desktop" ];
        "image/bmp" = [ "org.gnome.Loupe.desktop" ];
        "image/tiff" = [ "org.gnome.Loupe.desktop" ];
        "image/svg+xml" = [ "org.gnome.Loupe.desktop" ];
      };

      wayland.windowManager.niri.settings._children = lib.mkAfter [
        {
          window-rule = {
            match._props."app-id" = "^org\\.gnome\\.Loupe$";
            # matches libadwaita's popover radius
            popups = {
              geometry-corner-radius = 15;
              background-effect.blur = true;
            };
          };
        }
      ];
    };
}
