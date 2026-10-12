{
  flake.modules.homeManager.yuxqiu-cedrus =
    { config, ... }:
    {
      my.happier.serverUrl = "https://${config.my.tailnetHosts.snowflake-dracaena}";
    };
}
