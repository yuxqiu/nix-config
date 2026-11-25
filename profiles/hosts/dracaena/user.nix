{
  # No GitHub credentials for the agent user: work leaves this box via cedrus
  # (a git remote over the tailnet), never by pushing from here.
  flake.modules.homeManager.dracaena =
    { config, lib, ... }:
    {
      programs.zsh.enable = true;

      programs.git.settings.user = {
        name = config.identity.name;
        email = config.identity.email;
      };
      # The signing key lives only in cedrus's SSH agent.
      programs.git.signing.signByDefault = lib.mkForce false;
    };
}
