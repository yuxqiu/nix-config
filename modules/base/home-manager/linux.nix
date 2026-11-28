{
  flake.modules.homeManager.base-linux =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        iputils
        patch
        traceroute
      ];
    };

  flake.modules.homeManager.base-linux-desktop =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        desktop-file-utils
        libnotify
        networkmanager
        xdg-utils
      ];
    };
}
