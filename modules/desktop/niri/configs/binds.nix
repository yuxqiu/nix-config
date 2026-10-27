{
  flake.modules.homeManager.niri = {
    wayland.windowManager.niri.settings.binds = {
      "Mod+Shift+Slash" = {
        show-hotkey-overlay = [ ];
      };

      "Mod+Q" = {
        _props.hotkey-overlay-title = null;
        close-window = [ ];
      };

      "Mod+O" = {
        _props.repeat = false;
        toggle-overview = [ ];
      };

      "Mod+H".focus-column-left = [ ];
      "Mod+J".focus-window-down = [ ];
      "Mod+K".focus-window-up = [ ];
      "Mod+L".focus-column-right = [ ];

      "Mod+Shift+H".move-column-left = [ ];
      "Mod+Shift+L".move-column-right = [ ];
      "Mod+Shift+J".consume-or-expel-window-left = [ ];
      "Mod+Shift+K".consume-or-expel-window-right = [ ];

      "Mod+Y".focus-monitor-next = [ ];
      "Mod+Shift+Y".move-column-to-monitor-next = [ ];

      "Mod+WheelScrollDown" = {
        _props.cooldown-ms = 150;
        focus-workspace-down = [ ];
      };
      "Mod+WheelScrollUp" = {
        _props.cooldown-ms = 150;
        focus-workspace-up = [ ];
      };
      "Mod+Ctrl+WheelScrollDown" = {
        _props.cooldown-ms = 150;
        move-column-to-workspace-down = [ ];
      };
      "Mod+Ctrl+WheelScrollUp" = {
        _props.cooldown-ms = 150;
        move-column-to-workspace-up = [ ];
      };
      "Mod+Ctrl+TouchpadScrollDown" = {
        _props.cooldown-ms = 150;
        move-column-to-workspace-down = [ ];
      };
      "Mod+Ctrl+TouchpadScrollUp" = {
        _props.cooldown-ms = 150;
        move-column-to-workspace-up = [ ];
      };

      "Mod+Ctrl+Shift+WheelScrollDown".move-column-right = [ ];
      "Mod+Ctrl+Shift+WheelScrollUp".move-column-left = [ ];
      "Mod+Ctrl+Shift+TouchpadScrollDown".move-column-right = [ ];
      "Mod+Ctrl+Shift+TouchpadScrollUp".move-column-left = [ ];

      "Mod+1".focus-workspace = 1;
      "Mod+2".focus-workspace = 2;
      "Mod+3".focus-workspace = 3;
      "Mod+4".focus-workspace = 4;
      "Mod+5".focus-workspace = 5;
      "Mod+6".focus-workspace = 6;
      "Mod+7".focus-workspace = 7;
      "Mod+8".focus-workspace = 8;
      "Mod+9".focus-workspace = 9;
      "Mod+0".focus-workspace = 10;

      "Mod+Shift+1".move-column-to-workspace = 1;
      "Mod+Shift+2".move-column-to-workspace = 2;
      "Mod+Shift+3".move-column-to-workspace = 3;
      "Mod+Shift+4".move-column-to-workspace = 4;
      "Mod+Shift+5".move-column-to-workspace = 5;
      "Mod+Shift+6".move-column-to-workspace = 6;
      "Mod+Shift+7".move-column-to-workspace = 7;
      "Mod+Shift+8".move-column-to-workspace = 8;
      "Mod+Shift+9".move-column-to-workspace = 9;
      "Mod+Shift+0".move-column-to-workspace = 10;

      "Mod+R".switch-preset-column-width = [ ];
      "Mod+T".switch-preset-window-height = [ ];
      "Mod+Shift+T".reset-window-height = [ ];
      "Mod+F".fullscreen-window = [ ];
      "Mod+Shift+F".maximize-column = [ ];
      "Mod+G".toggle-window-floating = [ ];
      "Mod+Shift+G".switch-focus-between-floating-and-tiling = [ ];

      "Mod+C".center-column = [ ];

      "Mod+Minus".set-column-width = "-10%";
      "Mod+Equal".set-column-width = "+10%";

      "Mod+Shift+Minus".set-window-height = "-10%";
      "Mod+Shift+Equal".set-window-height = "+10%";

      "Mod+W".toggle-column-tabbed-display = [ ];

      "Mod+P".screenshot._props.show-pointer = false;
      "Mod+Shift+P".screenshot-window = [ ];

      "Mod+Escape" = {
        _props."allow-inhibiting" = false;
        toggle-keyboard-shortcuts-inhibit = [ ];
      };

      "Mod+Shift+E".quit = [ ];

      "Mod+Shift+M".spawn = [
        "niri"
        "msg"
        "output"
        "eDP-1"
        "on"
      ];
    };
  };
}
