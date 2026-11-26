{ inputs, ... }:
{
  flake.modules.homeManager.nix = {
    # Fetched flake inputs and the evaluation cache (several GB); without it
    # the first evaluation after a reboot downloads every input again.
    persistence.directories = [ ".cache/nix" ];
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
