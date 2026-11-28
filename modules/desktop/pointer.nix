{
  flake.modules.homeManager.pointer =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        wl-kbptr
        wlrctl
      ];

      # Only what differs from wl-kbptr's defaults (section_defs in
      # src/config.c), plus defaults the menu below relies on.
      xdg.configFile."wl-kbptr/config".text = ''
        [mode_floating]
        selectable_bg_color=#0018
        label_font_size=18 50% 100

        # The menu's click modes press the left button.
        [mode_click]
        button=left
      '';

      programs.wlr-which-key.extraMenus.pointer = {
        background = "#282828d0";
        color = "#fbf1c7";
        border = "#8ec07c";
        separator = " ➜ ";
        border_width = 2;
        corner_r = 10;
        padding = 15;
        rows_per_column = 5;
        column_padding = 25;
        anchor = "center";
        inhibit_compositor_keyboard_shortcuts = true;
        auto_kbd_layout = true;

        menu = [
          {
            key = "g";
            desc = "Detect";
            cmd = "wl-kbptr -o modes=floating,click -o mode_floating.source=detect";
          }
          {
            key = "b";
            desc = "Bisect";
            cmd = "wl-kbptr -o modes=tile,bisect,click";
          }
          {
            key = "h";
            desc = "← left";
            cmd = "wlrctl pointer move -10 0";
            keep_open = true;
          }
          {
            key = "j";
            desc = "↓ down";
            cmd = "wlrctl pointer move 0 10";
            keep_open = true;
          }
          {
            key = "k";
            desc = "↑ up";
            cmd = "wlrctl pointer move 0 -10";
            keep_open = true;
          }
          {
            key = "l";
            desc = "→ right";
            cmd = "wlrctl pointer move 10 0";
            keep_open = true;
          }
          {
            key = "s";
            desc = "Click Left";
            cmd = "wlrctl pointer click left";
            keep_open = true;
          }
          {
            key = "d";
            desc = "Click Middle";
            cmd = "wlrctl pointer click middle";
            keep_open = true;
          }
          {
            key = "f";
            desc = "Click Right";
            cmd = "wlrctl pointer click right";
            keep_open = true;
          }
          {
            key = "Up";
            desc = "Scroll ↑";
            cmd = "wlrctl pointer scroll -10 0";
            keep_open = true;
          }
          {
            key = "Down";
            desc = "Scroll ↓";
            cmd = "wlrctl pointer scroll 10 0";
            keep_open = true;
          }
          {
            key = "Left";
            desc = "Scroll ←";
            cmd = "wlrctl pointer scroll 0 -10";
            keep_open = true;
          }
          {
            key = "Right";
            desc = "Scroll →";
            cmd = "wlrctl pointer scroll 0 10";
            keep_open = true;
          }
        ];
      };
    };
}
