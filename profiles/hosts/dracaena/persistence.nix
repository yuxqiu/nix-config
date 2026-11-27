{
  flake.modules.nixos.dracaena = {
    # The btrfs subvolume @persist (disko.nix); kept paths are bind-mounted
    # from the same paths under it.
    persistence.storage = "/persist";

    # Bind mounts of kept directories exist only after activation, when
    # secrets are installed, so the key is read from the subvolume itself.
    sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt";
  };
}
