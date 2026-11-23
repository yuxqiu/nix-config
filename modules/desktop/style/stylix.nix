{ inputs, ... }:

{
  flake.modules.homeManager.stylix =
    {
      lib,
      options,
      pkgs,
      ...
    }:
    let
      stylixHasWaypromptTarget = options.stylix.targets ? wayprompt;
    in
    {
      imports = [ inputs.stylix.homeModules.stylix ];

      # Home Manager removed programs.wayprompt, but stylix's wayprompt target
      # still defines it, which fails Home Manager's removed-option assertion.
      stylix.targets = lib.optionalAttrs stylixHasWaypromptTarget { wayprompt.enable = false; };
      warnings = lib.optional (!stylixHasWaypromptTarget) "modules/desktop/style/stylix.nix: stylix dropped its wayprompt target. Remove the stylix.targets.wayprompt override, the stylixHasWaypromptTarget binding, and this warning.";

      stylix = {
        enable = true;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
        polarity = "dark";

        fonts = {
          sansSerif = {
            package = pkgs.fira;
            name = "Fira Sans";
          };

          serif = {
            package = pkgs.fira;
            name = "Fira Sans";
          };

          monospace = {
            package = pkgs.nerd-fonts.fira-code;
            name = "FiraCode Nerd Font Mono";
          };

          emoji = {
            package = pkgs.noto-fonts-color-emoji;
            name = "Noto Color Emoji";
          };
        };

        opacity = {
          desktop = 0.8;
          applications = 1.0;
          terminal = 0.8;
          popups = 0.8;
        };

        icons = {
          enable = true;
          package = pkgs.adwaita-icon-theme;
          light = "Adwaita";
          dark = "Adwaita";
        };

        cursor = {
          name = "Adwaita";
          package = pkgs.adwaita-icon-theme;
          size = 24;
        };
      };

      home.file.".wallpapers".source = ./wallpapers;
    };
}
