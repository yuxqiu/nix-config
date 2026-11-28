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

      services.opensnitch-ui.enable = true;
      # opensnitch-ui 1.8.0 aborts when a prompt opens and Qt cannot tell
      # which screen the cursor is on (always so on Wayland):
      # dialogs/prompt move_popup calls availableGeometry() on the None that
      # virtualSiblingAt() returns. Restarted so the next connection still
      # gets a prompt. Upstream master checks for None; no release has it yet.
      systemd.user.services.opensnitch-ui = {
        Service = {
          Restart = "on-failure";
          RestartSec = "5";
        };
      };
      warnings = lib.optional (lib.versionOlder "1.8.0" pkgs.opensnitch-ui.version) "modules/networking/opensnitch.nix: opensnitch-ui is now ${pkgs.opensnitch-ui.version}. If its dialogs/prompt move_popup checks virtualSiblingAt() for None, remove Restart/RestartSec from the opensnitch-ui unit and this warning.";

      wayland.windowManager.niri.settings._children = lib.mkAfter [
        {
          window-rule = {
            match._props."app-id" = "opensnitch_ui";
            background-effect.blur = true;
            opacity = config.stylix.opacity.popups;
            # menu translucency comes from modules/desktop/style/qt.nix
            popups.background-effect.blur = true;
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
    persistence.directories = [ "/var/lib/opensnitch" ];
    services.opensnitch.enable = true;

    # Connections no rule matches are denied whenever no UI answers (before
    # login, or after the UI is stopped or replaced by another process
    # serving its socket), instead of allowed.
    services.opensnitch.settings.DefaultAction = "deny";
  };
}
