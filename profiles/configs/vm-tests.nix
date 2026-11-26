{ config, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # VM tests: nix build .#checks.<system>.<name> (sops-pq, sops-pq-install, impermanence)
      checks.sops-pq = import ../../tests/sops-pq.nix {
        inherit pkgs;
        nixosSops = config.flake.modules.nixos.sops;
      };
      checks.sops-pq-install = import ../../tests/sops-pq-install.nix {
        inherit pkgs;
        nixosSops = config.flake.modules.nixos.sops;
        inherit (inputs.disko.nixosModules) disko;
      };
      checks.impermanence = import ../../tests/impermanence.nix {
        inherit pkgs;
        nixosSops = config.flake.modules.nixos.sops;
        nixosImpermanence = config.flake.modules.nixos.impermanence;
        nixosBase = config.flake.modules.nixos.base;
        genericBase = config.flake.modules.generic.base;
      };
    };
}
