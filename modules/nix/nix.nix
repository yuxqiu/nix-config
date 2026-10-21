{ inputs, ... }:
{
  flake.modules.homeManager.nix = {
    nix = {
      enable = true;
      # Manage nixpkgs channel used by
      # nix-shell
      channels = {
        inherit (inputs) nixpkgs;
      };
    };
  };
}
