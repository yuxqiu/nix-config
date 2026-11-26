{
  flake.modules.homeManager.jan = { pkgs, ... }: {
    persistence.directories = [ ".local/share/Jan" ];
    home.packages = with pkgs; [ jan ];
  };
}
