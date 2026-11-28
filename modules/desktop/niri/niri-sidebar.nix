{
  flake.modules.homeManager.niri =
    { pkgs, lib, ... }:
    {
      home.packages = [ pkgs.niri-sidebar ];

      # niri-sidebar reads $XDG_CONFIG_HOME/niri-sidebar/config.toml
      # (dirs::config_dir in src/config.rs).
      xdg.configFile."niri-sidebar/config.toml".text = ''
        [geometry]
        width = 550
        height = 335
        gap = 15

        [margins]
        top = 30
        right = 20
        bottom = 50

        [interaction]
        position = "right"
        peek = 70
        focus_peek = 70
        sticky = false
      '';

      wayland.windowManager.niri.settings = {
        binds = {
          "Mod+A" = {
            _props.hotkey-overlay-title = "Toggle Sidebar Floating";
            spawn-sh = "niri-sidebar toggle-window";
          };
          "Mod+Shift+A" = {
            _props.hotkey-overlay-title = "Toggle Sidebar Visibility";
            spawn-sh = "niri-sidebar toggle-visibility";
          };
        };

        _children = lib.mkAfter [
          {
            spawn-at-startup._args = [
              "niri-sidebar"
              "listen"
            ];
          }
        ];
      };
    };
}
