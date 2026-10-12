{
  config,
  ...
}:

{
  configurations.nixos = {
    "snowflake-dracaena" = {
      system = "aarch64-linux";
      stateVersion = "26.11";
      modules = [
        config.flake.modules.generic.base
        config.flake.modules.generic.yuxqiu

        # base
        config.flake.modules.nixos.base

        # networking
        config.flake.modules.nixos.dns
        config.flake.modules.nixos.networking
        config.flake.modules.nixos.firewall
        config.flake.modules.nixos.tailscale

        # security
        config.flake.modules.nixos.sysctl
        config.flake.modules.nixos.coredump

        # services
        config.flake.modules.nixos.journald
        config.flake.modules.nixos.fstrim

        config.flake.modules.nixos.snowflake-dracaena
      ];
      homeManager.username = "snowflake";
      homeManager.stateVersion = "26.11";
      homeManager.modules = [
        config.flake.modules.generic.base
        config.flake.modules.generic.yuxqiu

        # base
        config.flake.modules.homeManager.base-linux

        # cli
        config.flake.modules.homeManager.git

        # dev (ai)
        config.flake.modules.homeManager.mcp
        config.flake.modules.homeManager.skills
        config.flake.modules.homeManager.agents-md
        config.flake.modules.homeManager.claude
        config.flake.modules.homeManager.codex

        # user
        config.flake.modules.homeManager.snowflake-dracaena
      ];
    };
  };
}
