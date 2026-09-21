{ inputs, ... }:
{
  flake.modules.homeManager.kangentic =
    { pkgs, ... }:
    {
      home.packages = [ (pkgs.callPackage (inputs.self + /packages/kangentic.nix) { }) ];
    };
}
