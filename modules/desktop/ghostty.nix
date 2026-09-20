{
  flake.modules.homeManager.ghostty =
    { lib, pkgs, ... }:
    {
      programs.ghostty = {
        enable = true;
        clearDefaultKeybinds = true;

        settings = {
          window-padding-x = 10;
          window-padding-y = 10;
          window-padding-balance = true;
          background-blur = true;
          background-opacity = 0.6;
          quit-after-last-window-closed = false;

          keybind = [
            "ctrl+alt+tab=next_tab"
            "ctrl+alt+shift+tab=previous_tab"
            "ctrl+alt+shift+t=new_tab"
            "ctrl+alt+shift+p=toggle_command_palette"
            "ctrl+alt+shift+w=close_tab:this"
            "ctrl+alt++=increase_font_size:1"
            "ctrl+alt+=increase_font_size:1"
            "ctrl+alt+-=decrease_font_size:1"
            "ctrl+alt+0=reset_font_size"
            "ctrl+alt+shift+f=start_search"
            "ctrl+alt+shift+n=new_window"
            "ctrl+shift+v=paste_from_clipboard"
            "ctrl+shift+c=copy_to_clipboard:mixed"

            "ctrl+alt+h=goto_split:left"
            "ctrl+alt+l=goto_split:right"
            "ctrl+alt+k=goto_split:top"
            "ctrl+alt+j=goto_split:bottom"
            "ctrl+alt+shift+h=new_split:left"
            "ctrl+alt+shift+l=new_split:right"
            "ctrl+alt+shift+k=new_split:up"
            "ctrl+alt+shift+j=new_split:down"

            "ctrl+alt+left=resize_split:left,10"
            "ctrl+alt+right=resize_split:right,10"
            "ctrl+alt+up=resize_split:up,10"
            "ctrl+alt+down=resize_split:down,10"

            "ctrl+backspace=text:\\x17"
            "ctrl+delete=text:\\x1b[3;5~"
          ];
        };

        systemd.enable = true;
      };

      xdg.terminal-exec = {
        settings = {
          default = [
            "com.mitchellh.ghostty.desktop"
          ];
        };
      };

      qt.kde.settings.kdeglobals.General = {
        TerminalApplication = "ghostty";
        TerminalService = "com.mitchellh.ghostty.desktop";
      };

      # Debian's `x-terminal-emulator` alternatives convention: some
      # third-party apps probe for this name specifically rather than
      # reading xdg-terminal-exec/kdeglobals.
      home.packages = [
        (pkgs.writeShellScriptBin "x-terminal-emulator" ''
          exec ghostty "$@"
        '')
      ];

      wayland.windowManager.niri.settings.binds."Mod+Return" = {
        _props.hotkey-overlay-title = "Open a Terminal: ghostty";
        spawn-sh = "ghostty +new-window";
      };

      wayland.windowManager.niri.settings._children = lib.mkAfter [
        {
          window-rule = {
            match._props."app-id" = "com.mitchellh.ghostty";
            background-effect.blur = true;
          };
        }
      ];
    };
}
