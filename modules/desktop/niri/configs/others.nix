{
  flake.modules.homeManager.niri = {
    wayland.windowManager.niri.settings = {
      hotkey-overlay.skip-at-startup = [ ];

      screenshot-path = null;

      prefer-no-csd = [ ];
    };
  };
}
