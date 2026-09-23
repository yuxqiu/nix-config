{
  flake.modules.homeManager.dms =
    { pkgs, ... }:
    {
      programs.dank-material-shell.plugins.niriDS.enable = true;

      home.packages = with pkgs; [
        wl-mirror
      ];
    };
}
