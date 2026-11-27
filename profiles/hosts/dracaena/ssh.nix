{
  flake.modules.nixos.dracaena =
    { config, ... }:
    {
      # The host keys sshd uses, so clients' known_hosts keeps matching.
      persistence.files = map (key: key.path) config.services.openssh.hostKeys;
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
