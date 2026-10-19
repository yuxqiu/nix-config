{
  flake.modules.homeManager.opensnitch =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home.packages = [ pkgs.opensnitch-ui ];

      # Add restart as opensnitch-ui is started too early and crashes consistently.
      services.opensnitch-ui.enable = true;
      systemd.user.services.opensnitch-ui = {
        Service = {
          Restart = "on-failure";
          RestartSec = "5";
        };
      };

      wayland.windowManager.niri.settings._children = lib.mkAfter [
        {
          window-rule = {
            match._props."app-id" = "opensnitch_ui";
            background-effect.blur = true;
            opacity = config.stylix.opacity.popups;
          };
        }

        {
          window-rule = {
            match._props."app-id" = "opensnitch_ui$";
            open-floating = true;
          };
        }
      ];
    };

  flake.modules.nixos.opensnitch = {
    services.opensnitch.enable = true;
  };
}
