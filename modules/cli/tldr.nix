{
  flake.modules.homeManager.tldr =
    { pkgs, ... }:
    let
      tldr-pages = pkgs.fetchFromGitHub {
        owner = "tldr-pages";
        repo = "tldr";
        rev = "74b1f7c21dd24d9a3cb51894ada376a9c066777c"; # follow:branch main
        hash = "sha256-Ha/3NAubYL7r/4w70q18ZDd5o/MxGYZlBff7bah5OAU=";
      };

      # tealdeer reads pages from <cache_dir>/tldr-pages/pages.<lang>/
      tldr-cache = pkgs.runCommand "tldr-cache" { } ''
        mkdir -p $out/tldr-pages
        ln -s ${tldr-pages}/pages $out/tldr-pages/pages.en
      '';
    in
    {
      programs.tealdeer = {
        enable = true;
        # pages come from the store; the default weekly `tldr --update` timer can only fail
        enableAutoUpdates = false;
        settings = {
          directories.cache_dir = "${tldr-cache}";
          # store paths have mtime 1970, so the age check would always warn
          updates.warn_cache_age = "never";
        };
      };
    };
}
