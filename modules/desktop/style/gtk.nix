{
  flake.modules.homeManager.gtk =
    { config, ... }:
    {
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
