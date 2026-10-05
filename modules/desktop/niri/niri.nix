{
  flake.modules.homeManager.niri =
    { pkgs, lib, ... }:
    {
      xdg.portal = {
        extraPortals = [
          pkgs.xdg-desktop-portal-gtk
          pkgs.xdg-desktop-portal-gnome
          pkgs.gnome-keyring
        ];

        config.niri = {
          default = [
            "gnome"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Access" = "gtk";
          "org.freedesktop.impl.portal.FileChooser" = "gnome";
          "org.freedesktop.impl.portal.Notification" = "gtk";
          "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
        };
      };

      home.packages = [
        # for gnome-keyring prompt to show
        # - https://github.com/nix-community/home-manager/issues/1454
        pkgs.gcr_4
      ];
      services.gnome-keyring.enable = true;

      wayland.windowManager.niri.enable = true;

      wayland.windowManager.niri.settings._children = lib.mkAfter [
        {
          window-rule = {
            match._props."app-id" = "gcr-prompter";
            background-effect.blur = true;
            opacity = 0.8;
          };
        }
      ];
    };

  flake.modules.nixos.niri =
    { pkgs, ... }:
    {
      programs.niri.enable = true;
    };
}
