{
  flake.modules.nixos.snowflake-dracaena =
    { config, ... }:
    {
      my.happier.serverUrl = "https://${config.my.tailnetHosts.snowflake-dracaena}";
    };

  flake.modules.homeManager.snowflake-dracaena =
    { config, ... }:
    {
      my.happier.serverUrl = "https://${config.my.tailnetHosts.snowflake-dracaena}";
    };
}
