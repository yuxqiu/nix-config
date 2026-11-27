{
  flake.modules.nixos.dracaena =
    { config, ... }:
    {
      # The host keys sshd uses, so clients' known_hosts keeps matching.
      # sshd refuses private keys others can read.
      persistence.files = map (key: {
        file = key.path;
        mode = "0600";
      }) config.services.openssh.hostKeys;
      services.openssh.enable = true;
      services.openssh.settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
      users.users.root.openssh.authorizedKeys.keys = [
        config.identity.keys."general-ssh"
      ];
    };
}
