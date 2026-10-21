{
  flake.modules.nixos.cedrus = {
    sops = {
      defaultSopsFile = ./secrets/cedrus.yaml;
      age.sshKeyPaths = [ "/etc/ssh/id_ed25519" ];
      age.generateKey = true;
    };
  };
}
