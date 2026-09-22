{
  flake.modules.homeManager.opensnitch =
    {
      pkgs,
      lib,
      ...
    }:
    let
      toggleOpensnitch = pkgs.writeShellApplication {
        name = "toggle-opensnitch";
        runtimeInputs = with pkgs; [ systemd ];
        text = ''
          set -euo pipefail

          action="$1"

          case "$action" in
            disable)
              if systemctl is-active --quiet opensnitchd; then
                echo "Disabling OpenSnitch..."
                sudo systemctl stop opensnitchd
              else
                echo "OpenSnitch is already disabled."
              fi
              ;;
            enable)
              if ! systemctl is-active --quiet opensnitchd; then
                echo "Re-enabling OpenSnitch..."
                sudo systemctl start opensnitchd
              fi
              ;;
            *)
              echo "Usage: toggle-opensnitch [disable|enable]"
              ;;
          esac
        '';
      };
    in
    {
      home.packages = [
        pkgs.opensnitch-ui
        toggleOpensnitch
      ];

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
            opacity = 0.6;
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
