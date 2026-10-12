let
  port = 6767;
in
{
  # The coordinator: this daemon also serves the web UI at the tailnet URL,
  # where the other hosts are added.
  flake.modules.nixos.snowflake-dracaena =
    { config, ... }:
    {
      services.paseo = {
        user = "snowflake";
        inherit port;
        hostnames = [ config.my.tailnetHosts.snowflake-dracaena ];
        settings.features.webUi.enabled = true;
      };

      services.tailscale.serve.services.paseo.endpoints = {
        "https:443" = "http://127.0.0.1:${toString port}";
      };
    };
}
