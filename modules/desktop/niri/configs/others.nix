{
  flake.modules.homeManager.niri = {
    wayland.windowManager.niri.settings = {
      hotkey-overlay.skip-at-startup = [ ];

      screenshot-path = null;

      prefer-no-csd = [ ];

      # DMS (via quickshell) sends no activation token when a notification
      # action is invoked, so apps like Slack fall back to requesting one
      # with an invalid serial, which niri ignores by default and the click
      # never focuses the window. Electron >= 42 already uses the daemon's
      # token, so drop this once quickshell sends one (see quickshell#1166
      # for the layer-shell token groundwork) and DMS passes it on.
      debug.honor-xdg-activation-with-invalid-serial = [ ];
    };
  };
}
