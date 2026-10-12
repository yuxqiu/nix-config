{ inputs, ... }:
{
  # Relay server, published to the tailnet only through `tailscale serve`.
  flake.modules.nixos.happier-server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      happier-server = pkgs.callPackage (inputs.self + /packages/happier-server.nix) { };
      port = 3005;
      cfg = config.my.happier;
    in
    {
      options.my.happier.serverUrl = lib.mkOption {
        type = lib.types.str;
        example = "https://relay.example.ts.net";
        description = "URL clients use to reach this server (it also serves the web UI).";
      };

      config = {
        systemd.services.happier-server = {
          description = "Happier relay server";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          environment = {
            PORT = toString port;
            HAPPIER_SERVER_HOST = "127.0.0.1";
            HAPPIER_SERVER_LIGHT_DATA_DIR = "/var/lib/happier-server";
            HAPPIER_PUBLIC_SERVER_URL = cfg.serverUrl;
            HAPPIER_WEBAPP_URL = cfg.serverUrl;
            HAPPIER_SERVER_TRUST_PROXY = "1";
            METRICS_ENABLED = "false";
          };
          # HANDY_MASTER_SECRET is generated on first start and kept in
          # handy-master-secret.txt beside the database; back the two up together.
          serviceConfig = {
            ExecStart = lib.getExe happier-server;
            DynamicUser = true;
            StateDirectory = "happier-server";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        services.tailscale.serve.services.happier-server.endpoints = {
          "https:443" = "http://127.0.0.1:${toString port}";
        };
      };
    };

  # CLI plus the daemon that runs agent sessions on this machine.
  flake.modules.homeManager.happier =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      happier = pkgs.callPackage (inputs.self + /packages/happier.nix) { };
      cfg = config.my.happier;
    in
    {
      options.my.happier.serverUrl = lib.mkOption {
        type = lib.types.str;
        example = "https://relay.example.ts.net";
        description = "URL of the Happier relay server (it also serves the web UI).";
      };

      config = {
        home.packages = [ happier ];

        home.sessionVariables = {
          HAPPIER_SERVER_URL = cfg.serverUrl;
          HAPPIER_WEBAPP_URL = cfg.serverUrl;
        };

        # Mirrors the unit `happier daemon install` would write.
        systemd.user.services.happier-daemon = {
          Unit = {
            Description = "Happier daemon";
            After = [ "network-online.target" ];
            Wants = [ "network-online.target" ];
          };
          Service = {
            ExecStart = "${lib.getExe happier} daemon start-sync --takeover";
            Environment = [
              "HAPPIER_SERVER_URL=${cfg.serverUrl}"
              "HAPPIER_WEBAPP_URL=${cfg.serverUrl}"
              "HAPPIER_NO_BROWSER_OPEN=1"
              # Idle until `happier auth login` has been run on this machine.
              "HAPPIER_DAEMON_WAIT_FOR_AUTH=1"
              "HAPPIER_DAEMON_WAIT_FOR_AUTH_TIMEOUT_MS=0"
              # Agent CLIs (claude, codex, ...) come from the user profile.
              "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
            ];
            # Agent sessions are child processes; let them outlive a daemon restart.
            KillMode = "process";
            Restart = "always";
            RestartSec = "2s";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    };
}
