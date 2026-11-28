{ inputs, ... }:

{
  flake.modules.homeManager.stylix =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.stylix.homeModules.stylix ];

      # Popup opacity as a whole percentage, rounded to nearest, for configs
      # that take an integer percent (Firefox menu CSS, Kvantum).
      lib.style.popupOpacityPercent = builtins.floor (config.stylix.opacity.popups * 100 + 0.5);

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
