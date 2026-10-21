{
  flake.modules.nixos.dracaena = {
    sops = {
      defaultSopsFile = ./secrets/dracaena.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      age.generateKey = true;
    };
  };
}
