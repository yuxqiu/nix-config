{
  flake.modules.homeManager.dms =
    { pkgs, ... }:
    {
      programs.dank-material-shell.plugins.screenkey = {
        enable = true;
        settings.visualizerEnabled = false;
      };

      home.packages = with pkgs; [
        evtest
        libinput
      ];
    };
}
