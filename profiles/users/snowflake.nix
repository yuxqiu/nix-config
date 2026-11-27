{
  # Login user for running coding agents over SSH. Key-only and no sudo.
  flake.modules.nixos.snowflake =
    { config, pkgs, ... }:
    {
      users.users.snowflake = {
        isNormalUser = true;
        shell = pkgs.zsh;
        openssh.authorizedKeys.keys = [ config.identity.keys."general-ssh" ];
        # Keys only: the password is locked. A declared hash is also what
        # immutable users (impermanence) require.
        hashedPassword = "!";
      };
    };
}
