{
  flake.modules.homeManager.zoom =
    { pkgs, ... }:
    {
      persistence.directories = [
        {
          directory = ".zoom";
          mode = "0700";
        }
      ];
      persistence.files = [
        {
          file = ".config/zoom.conf";
          mode = "0600";
        }
        ".config/zoomus.conf"
      ];
      home.packages = with pkgs; [ zoom-us ];
    };
}
