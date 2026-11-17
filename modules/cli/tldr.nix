{
  flake.modules.homeManager.tldr =
    { pkgs, ... }:
    let
      tldr-pages = pkgs.fetchFromGitHub {
        owner = "tldr-pages";
        repo = "tldr";
        rev = "1d22cad212727e60367d34448220134af98e82b5"; # follow:branch main
        hash = "sha256-w2i5YB96meVzbFXUuYIgefscs8tDSBpt+HYb/TXBBFM=";
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
