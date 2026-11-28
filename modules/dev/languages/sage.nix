{
  flake.modules.homeManager.sage =
    { pkgs, ... }:
    {
      dev.languages.sage = {
        packages = [ pkgs.sage ];
      };
    };
}
