let
  port = "4433";
in
{
  flake.modules.nixos.cedrus = {
    services.tailscale.serve.services.hister.endpoints = {
      "https:${port}" = "http://127.0.0.1:${port}";
    };
  };

  flake.modules.homeManager.cedrus =
    { config, ... }:
    {
      services.hister.settings.server = {
        address = "127.0.0.1:${port}";
        base_url = "https://${config.my.tailnetHosts.cedrus}:${port}";
      };
    };
}
