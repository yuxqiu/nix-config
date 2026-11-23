{
  flake.modules.homeManager.tldr =
    { pkgs, ... }:
    let
      tldr-pages = pkgs.fetchFromGitHub {
        owner = "tldr-pages";
        repo = "tldr";
        rev = "4aa51fc35107a64631c202f9935ece7e250f811b"; # follow:branch main
        hash = "sha256-4g69e27n2vGwJtG90v16Di8dW8Cz5eaIXd13w55wO3M=";
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
