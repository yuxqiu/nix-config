{ lib, ... }:
{
  flake.modules.homeManager.niri =
    { config, ... }:
    let
      # Windows being screencast are marked red: the theme's red when
      # focused, and niri's documented dark red for this rule otherwise,
      # which has no matching theme colour.
      castActive = config.lib.stylix.colors.withHashtag.base08;
      castInactive = "#7d0d2d";
    in
    {
      wayland.windowManager.niri.settings._children = lib.mkAfter [
        {
          window-rule = {
            geometry-corner-radius = 12;
            clip-to-geometry = true;
          };
        }

        {
          window-rule = {
            match._props."is-window-cast-target" = true;
            focus-ring = {
              active-color = castActive;
              inactive-color = castInactive;
            };
            tab-indicator = {
              active-color = castActive;
              inactive-color = castInactive;
            };
          };
        }
      ];
    };
}
