{ lib, ... }:
let
  # Mod+1 … Mod+9 and Mod+0 focus workspaces 1 to 10; with Shift they move
  # the focused column there.
  workspaceBinds = lib.listToAttrs (
    lib.concatMap (
      n:
      let
        key = toString (lib.mod n 10);
      in
      [
        (lib.nameValuePair "Mod+${key}" { focus-workspace = n; })
        (lib.nameValuePair "Mod+Shift+${key}" { move-column-to-workspace = n; })
      ]
    ) (lib.range 1 10)
  );
in
{
  flake.modules.homeManager.niri = {
    wayland.windowManager.niri.settings.binds = workspaceBinds // {
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
    };
  };
}
