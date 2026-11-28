{ inputs, ... }:
{
  flake.modules.homeManager.nix-update =
    { pkgs, ... }:
    {
      home.packages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nix-update-git
      ];
    };
}
