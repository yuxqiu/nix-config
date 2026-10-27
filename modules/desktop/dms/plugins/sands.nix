{
  flake.modules.homeManager.dms =
    { pkgs, ... }:
    {
      programs.dank-material-shell.plugins.smartTimer.enable = true;

      home.packages = with pkgs; [
        pipewire # pw-play
        libnotify # notify-send
        glib # gdbus
      ];
    };
}
