{
  flake.modules.nixos.dracaena = {
    # The btrfs subvolume @persist (disko.nix); kept paths are bind-mounted
    # from the same paths under it.
    persistence.storage = "/persist";

  };
}
