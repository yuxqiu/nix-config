{ inputs, ... }:
{
  flake.modules.homeManager.base =
    { pkgs, ... }:
    {
      home.packages = [ (pkgs.callPackage (inputs.self + /packages/sops-tools.nix) { }) ];
    };
}
