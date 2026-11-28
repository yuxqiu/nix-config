{
  flake.modules.homeManager.base =
    { pkgs, ... }:
    {
      programs.home-manager.enable = true;

      home.shell = {
        enableBashIntegration = true;
        enableZshIntegration = true;
      };

      home.packages = with pkgs; [
        cargo-flamegraph
        ffmpeg
        pandoc
        tokei
        typos
        zmk-studio
      ];
    };
}
