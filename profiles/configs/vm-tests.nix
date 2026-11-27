{ config, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # VM tests: nix build .#checks.<system>.<name> (sops-pq, sops-pq-install, ephemeral-root, desktop-convert)
      checks.sops-pq = import ../../tests/sops-pq.nix {
        inherit pkgs;
        nixosSops = config.flake.modules.nixos.sops;
        genericBase = config.flake.modules.generic.base;
      };
      checks.sops-pq-install = import ../../tests/sops-pq-install.nix {
        inherit pkgs;
        nixosSops = config.flake.modules.nixos.sops;
        genericBase = config.flake.modules.generic.base;
        inherit (inputs.disko.nixosModules) disko;
      };
      checks.desktop-convert = import ../../tests/desktop-convert.nix {
        inherit pkgs;
        nixosEphemeralRoot = config.flake.modules.nixos.ephemeral-root;
        nixosBase = config.flake.modules.nixos.base;
        genericBase = config.flake.modules.generic.base;
      };
      checks.disko-wait = import ../../tests/disko-wait.nix {
        inherit pkgs;
        inherit (inputs.disko.nixosModules) disko;
      };
      checks.ephemeral-root = import ../../tests/ephemeral-root.nix {
        inherit pkgs;
        nixosEphemeralRoot = config.flake.modules.nixos.ephemeral-root;
        nixosBase = config.flake.modules.nixos.base;
        genericBase = config.flake.modules.generic.base;
      };
    };
}
