let
  port = 3005;
in
{
  flake.modules.nixos.snowflake-dracaena =
    { config, ... }:
    {
      my.happier = {
        serverUrl = "https://${config.my.tailnetHosts.snowflake-dracaena}";
        inherit port;
      };
    };

  flake.modules.homeManager.snowflake-dracaena =
    { config, ... }:
    {
      # A connection to this host's own tailnet address bypasses
      # `tailscale serve` (xray answers on :443 instead), so the local daemon
      # connects over loopback while still naming the server by its tailnet URL.
      my.happier = {
        serverUrl = "https://${config.my.tailnetHosts.snowflake-dracaena}";
        localServerUrl = "http://127.0.0.1:${toString port}";
      };
    };
}
