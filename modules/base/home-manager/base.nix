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
        bottom
        cargo-flamegraph
        dig
        duf
        fastfetch
        ffmpeg
        jq
        less
        mtr
        openssl
        pandoc
        rsync
        screen
        sqlite
        strace
        tokei
        tree
        typos
        wget
        which
        zmk-studio
      ];
    };
}
