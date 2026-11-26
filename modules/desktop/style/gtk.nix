{
  flake.modules.homeManager.gtk =
    { config, ... }:
    {
      # The file manager's sidebar bookmarks, edited in the file chooser. GLib
      # replaces the bookmarks file by rename, and GTK reads it only from this
      # directory, so the directory is kept rather than the file.
      persistence.directories = [ ".config/gtk-3.0" ];
      gtk = {
        enable = true;
        colorScheme = "dark";
      };

      # Translucent GTK4 menus, blurred by niri `popups` window rules. Niri
      # blurs a rectangle, so menus with an arrow (from header bar buttons)
      # don't blur cleanly around the arrow tip.
      stylix.targets.gtk.extraCss = ''
        popover.menu > contents,
        popover.menu > arrow {
          background-color: alpha(@popover_bg_color, ${toString config.stylix.opacity.popups});
        }
      '';
    };
}
