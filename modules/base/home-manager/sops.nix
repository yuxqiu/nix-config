{ inputs, ... }:
{
  flake.modules.homeManager.base =
    { pkgs, ... }:
    {
      home.packages = [ (pkgs.callPackage (inputs.self + /packages/sops-tools.nix) { }) ];
    };

  # Also a flake package, so a machine not yet running this config can use
  # the tools from a checkout: `nix shell .#sops-tools`.
  perSystem =
    { pkgs, ... }:
    {
      packages.sops-tools = pkgs.callPackage (inputs.self + /packages/sops-tools.nix) { };
    };
}
