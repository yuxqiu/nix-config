{
  flake.modules.homeManager.zoom =
    { pkgs, ... }:
    {
      persistence.directories = [ ".zoom" ];
      persistence.files = [
        ".config/zoom.conf"
        ".config/zoomus.conf"
      ];
      home.packages = with pkgs; [ zoom-us ];
    };
}
