{ inputs, ... }:
{
  flake.modules.homeManager.lig =
    { config, ... }:
    let
      c = config.lib.stylix.colors.withHashtag;
    in
    {
      imports = [ inputs.lig.homeModules.default ];

      programs.lig = {
        enable = true;
        settings = {
          # The stylix monospace font is a Nerd Font; skip lig's fc-list probe.
          ui.icons = "nerd";
          # Stylix palette, but keep the terminal's own background (and its
          # opacity/blur), as in fzf.nix.
          colors = {
            bg = "default";
            border_bg = "default";
            fg = c.base05;
            selected_bg = c.base02;
            selected_fg = c.base05;
            description_fg = c.base04;
            selected_description_fg = c.base05;
            match_fg = c.base0D;
            border_fg = c.base03;
            scrollbar_fg = c.base02;
            scrollbar_thumb = c.base04;
            info_fg = c.base04;
          };
        };
      };
    };
}
