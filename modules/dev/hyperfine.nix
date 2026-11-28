{
  flake.modules.homeManager.hyperfine =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.hyperfine ];
    };
}
