let
  port = 6767;
in
{
  flake.modules.nixos.yuxqiu-cedrus =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Paseo runs on a shared node, which OpenSnitch can't tell apart from
      # any other node program. Give it a private copy of the node the package
      # was built with, named `paseo`, for the firewall rules below to match.
      paseoNode = lib.getExe' pkgs.paseo.nodejs "node";
      paseo = pkgs.runCommand "paseo-standalone" { } ''
        install -Dm755 ${paseoNode} $out/libexec/paseo/paseo
        mkdir -p $out/bin
        substitute ${pkgs.paseo}/bin/paseo-server $out/bin/paseo-server \
          --replace-fail ${paseoNode} $out/libexec/paseo/paseo
        chmod +x $out/bin/paseo-server
        ln -s ${pkgs.paseo}/bin/paseo $out/bin/paseo
      '';
      paseoBin = "${paseo}/libexec/paseo/paseo";
    in
    {
      services.paseo = {
        package = paseo;
        user = "yuxqiu";
        inherit port;
        hostnames = [ config.my.tailnetHosts.yuxqiu-cedrus ];
        # The web UI is served by dracaena; let it connect to this daemon.
        settings.daemon.cors.allowedOrigins = [
          "https://${config.my.tailnetHosts.snowflake-dracaena}"
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
