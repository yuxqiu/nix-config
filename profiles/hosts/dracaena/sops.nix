{
  flake.modules.nixos.dracaena = {
    sops = {
      defaultSopsFile = ./secrets/dracaena.yaml;
    };
  };
}
