{ inputs, ... }:
{
  flake.modules.homeManager.disktree =
    { pkgs, ... }:
    let
      disktree = pkgs.callPackage (inputs.self + /packages/disktree.nix) { };
    in
    {
      home.packages = [ disktree ];
    };
}
