{
  flake.modules.homeManager.niri = {
    wayland.windowManager.niri.settings.layout = {
      gaps = 10;

      preset-column-widths._children = [
        { proportion = 0.33333; }
        { proportion = 0.5; }
        { proportion = 0.66667; }
      ];

      default-column-width.proportion = 0.5;

      # Colours from niri's default config (resources/default-config.kdl);
      # the theme has no matching colours.
      focus-ring = {
        width = 1;
        active-color = "#7fc8ff";
        inactive-color = "#505050";
      };

      border.off = [ ];
    };
  };
}
