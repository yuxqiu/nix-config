{ inputs, ... }:
{
  flake.modules.homeManager.quicksnip =
    {
      pkgs,
      ...
    }:
    {
      home.packages = [ inputs.quicksnip.packages.${pkgs.stdenv.system}.default ];

      # QuickSnip reads $XDG_CONFIG_HOME/quickshell/QuickSnip/settings.json
      # (shell.qml); the package passes its QML directory to quickshell with -p,
      # so this directory holds only the settings.
      xdg.configFile."quickshell/QuickSnip/settings.json".text = builtins.toJSON {
        Search = {
          engine = "google";
          open_in = "newtab";
        };
        Selection = {
          style = "rectangle";
        };
        Translation = {
          target_lang = "zh-CN";
          open_in = "newtab";
        };
        AI = {
          provider = "chatgpt";
          open_in = "newtab";
        };
        Lens = {
          open_in = "newtab";
        };
        Smart = {
          ai_threshold = 15;
          open_in = "newtab";
        };
        # Window that "sidebar" mode focuses with `wlrctl window focus`, which
        # matches the app id; Firefox's is "firefox".
        Browser = {
          class = "firefox";
        };
      };

      wayland.windowManager.niri.settings.binds."Mod+E" = {
        _props.hotkey-overlay-title = "QuickSnip";
        spawn = "quicksnip";
      };
    };
}
