{
  flake.modules.homeManager.tldr =
    { pkgs, ... }:
    let
      tldr-pages = pkgs.fetchFromGitHub {
        owner = "tldr-pages";
        repo = "tldr";
        rev = "29f42da3a552ec8ce6ca6a7a399c53d7c4924829"; # follow:branch main
        hash = "sha256-4pZu13KiNAf81MfTzuLOO+GLSkKkoqIUp+IKDUKB13U=";
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
        settings = {
          directories.cache_dir = "${tldr-cache}";
          # store paths have mtime 1970, so the age check would always warn
          updates.warn_cache_age = "never";
        };
      };
    };
}
