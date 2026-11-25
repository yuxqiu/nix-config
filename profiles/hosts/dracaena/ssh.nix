{
  flake.modules.nixos.dracaena =
    { config, ... }:
    {
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
