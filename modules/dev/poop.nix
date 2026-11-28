{
  flake.modules.homeManager.poop =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.poop ];
    };
}
