{
  # Login user for agents run by the Happier daemon. Key-only, no sudo, and
  # no GitHub credentials: work leaves this box via cedrus (handoff or a git
  # remote over the tailnet), never by pushing from here.
  flake.modules.nixos.snowflake-dracaena =
    { config, pkgs, ... }:
    {
      users.users.snowflake = {
        isNormalUser = true;
        shell = pkgs.zsh;
        openssh.authorizedKeys.keys = [ config.my.user.keys."general-ssh" ];
        # Keep the user's systemd instance (and the Happier daemon) running
        # without an active login.
        linger = true;
      };

      services.openssh.settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

  flake.modules.homeManager.snowflake-dracaena =
    { config, lib, ... }:
    {
      programs.zsh.enable = true;

      programs.git.settings.user = {
        name = config.my.user.name;
        email = config.my.user.email;
      };
      # The signing key lives only in cedrus's SSH agent.
      programs.git.signing.signByDefault = lib.mkForce false;
    };
}
