{ config, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # VM tests: nix build .#checks.<system>.sops-pq (and sops-pq-install)
      checks.sops-pq = import ../../tests/sops-pq.nix {
        inherit pkgs;
        nixosSops = config.flake.modules.nixos.sops;
      };
      checks.sops-pq-install = import ../../tests/sops-pq-install.nix {
        inherit pkgs;
        nixosSops = config.flake.modules.nixos.sops;
        inherit (inputs.disko.nixosModules) disko;
      };
    };
}
