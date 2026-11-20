{
  flake.modules.homeManager.tldr =
    { pkgs, ... }:
    let
      tldr-pages = pkgs.fetchFromGitHub {
        owner = "tldr-pages";
        repo = "tldr";
        rev = "2cecf67fb258cb29d357491534956380b8ad8669"; # follow:branch main
        hash = "sha256-TqROJ4o0sm/3vvp2EX/YTaeNEhaDkBxdywckySf5/L4=";
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
