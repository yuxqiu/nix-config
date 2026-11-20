let
  port = 6767;
in
{
  # The coordinator: this daemon also serves the web UI at the tailnet URL,
  # where the other hosts are added.
  flake.modules.nixos.dracaena =
    { config, ... }:
    {
      services.paseo = {
        user = "snowflake";
        inherit port;
        hostnames = [ config.my.tailnetHosts.dracaena ];
        settings.features.webUi.enabled = true;
      };

      services.tailscale.serve.services.paseo.endpoints = {
        "https:443" = "http://127.0.0.1:${toString port}";
      };
    };

  # Paseo's orchestration skills (what the UI's "Install" would copy), from the
  # source of the packaged Paseo so they match the daemon. Skills are global to
  # the user, so only here, where agents only ever run through Paseo.
  flake.modules.homeManager.dracaena =
    { pkgs, ... }:
    {
      programs.agent-skills = {
        sources.paseo = {
          path = pkgs.paseo.src;
          subdir = "skills";
        };
        skills.enableAll = [ "paseo" ];
      };
    };
}
