{
  flake.modules.nixos.cedrus = {
    sops = {
      defaultSopsFile = ./secrets/cedrus.yaml;
    };
  };
}
