{
  flake.modules.homeManager.markdown =
    { pkgs, ... }:
    {
      dev.languages.markdown = {
        packages = [ pkgs.markdown-oxide ];
      };
    };
}
