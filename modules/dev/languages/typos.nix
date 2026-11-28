{
  flake.modules.homeManager.typos =
    { pkgs, ... }:
    {
      dev.languages.typos = {
        packages = [ pkgs.typos-lsp ];
      };
    };
}
