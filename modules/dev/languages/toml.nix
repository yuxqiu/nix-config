{
  flake.modules.homeManager.toml =
    { pkgs, ... }:
    {
      dev.languages.toml = {
        # taplo is both language server and formatter.
        packages = [ pkgs.taplo ];
      };
    };
}
