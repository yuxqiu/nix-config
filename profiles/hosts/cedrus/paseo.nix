{ inputs, ... }:
let
  port = 6767;
in
{
  flake.modules.nixos.cedrus =
    { config, pkgs, ... }:
    let
      # A private node copy for the OpenSnitch rules below to match.
      paseo = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.paseo-standalone;
      paseoBin = "${paseo}/libexec/paseo/paseo";
    in
    {
      services.paseo = {
        package = paseo;
        user = "yuxqiu";
        inherit port;
        hostnames = [ config.tailnet.cedrus ];
        # The web UI is served by dracaena; let it connect to this daemon.
        settings.daemon.cors.allowedOrigins = [
          "https://${config.tailnet.dracaena}"
        ];
      };

      services.tailscale.serve.services.paseo.endpoints = {
        "https:${toString port}" = "http://127.0.0.1:${toString port}";
      };

      # Agents run unattended, so nobody answers OpenSnitch prompts: allow the
      # daemon and everything it launches. Other programs keep prompting.
      services.opensnitch.rules = {
        paseo-daemon = {
          name = "paseo-daemon";
          enabled = true;
          action = "allow";
          duration = "always";
          operator = {
            type = "simple";
            operand = "process.path";
            data = paseoBin;
          };
        };
        paseo-agents = {
          name = "paseo-agents";
          enabled = true;
          action = "allow";
          duration = "always";
          operator = {
            type = "simple";
            operand = "process.parent.path";
            data = paseoBin;
          };
        };
      };
    };
}
