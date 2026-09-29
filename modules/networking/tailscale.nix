{
  flake.modules.nixos.tailscale =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.tailscale.serve;

      serveServiceType = lib.types.submodule {
        options = {
          endpoints = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            description = ''
              Map of incoming traffic patterns to local targets.

              Keys should be in the format `<protocol>:<port>`.
              Supported protocols: https, http, tcp.

              Values should be in the format `<protocol>://<host>:<port>`.
            '';
            example = lib.literalExpression ''
              {
                "https:4433" = "http://127.0.0.1:4433";
                "tcp:6767" = "tcp://127.0.0.1:6767";
              }
            '';
          };
          advertised = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = ''
              Whether the service should accept new connections.
              Defaults to null when not specified.
            '';
          };
        };
      };

      serveCommands =
        let
          mkCmd =
            name: serviceCfg:
            let
              endpointCmds = lib.mapAttrsToList (
                listener: target:
                let
                  parts = lib.splitString ":" listener;
                  proto = lib.head parts;
                  port = lib.last parts;
                in
                "tailscale serve --bg --${proto} ${port} ${target}"
              ) serviceCfg.endpoints;
              advertiseCmd =
                if serviceCfg.advertised == true then
                  "tailscale serve advertise svc:${name}"
                else if serviceCfg.advertised == false then
                  "tailscale serve drain svc:${name}"
                else
                  "";
            in
            lib.concatStringsSep "\n" (endpointCmds ++ lib.optional (advertiseCmd != "") advertiseCmd);
        in
        lib.concatStringsSep "\n" (lib.mapAttrsToList mkCmd cfg.services);

      tailscaleServeScript = pkgs.writeShellApplication {
        name = "tailscale-serve";
        runtimeInputs = [
          pkgs.tailscale
          pkgs.jq
        ];
        text = ''
          getState() {
            tailscale status --json --peers=false | jq -r '.BackendState'
          }

          lastState=""
          while state="$(getState)"; do
            if [[ "$state" != "$lastState" ]]; then
              case "$state" in
                Running)
                  echo "Tailscale is running, configuring serve"
                  ${serveCommands}
                  exit 0
                  ;;
                NeedsLogin|NeedsMachineAuth|Stopped)
                  echo "Tailscale not ready, waiting for state = Running"
                  ;;
                *)
                  echo "Waiting for Tailscale State = Running or systemd timeout"
                  ;;
              esac
              echo "State = $state"
            fi
            lastState="$state"
            sleep .5
          done
        '';
      };

      hasServices = cfg.services != { };
    in
    {
      # NOTE: upstream only configures Tailscale Services (svc:, `serve set-config`),
      # which requires a tagged host and admin-console service definitions. This
      # module does node-level serve on the machine's own MagicDNS name instead.
      disabledModules = [ "services/networking/tailscale-serve.nix" ];

      options.services.tailscale.serve = {
        enable = lib.mkEnableOption "Tailscale Serve configuration";

        services = lib.mkOption {
          type = lib.types.attrsOf serveServiceType;
          default = { };
          description = ''
            Services to configure for Tailscale Serve.

            Each attribute name should be the service name (without the `svc:` prefix).
            The `svc:` prefix will be added automatically when advertising.

            Mirrors the structure of the upstream services.tailscale.serve.services
            option for easy future migration when the upstream supports all protocols.
          '';
          example = lib.literalExpression ''
            {
              hister = {
                endpoints = {
                  "https:4433" = "http://127.0.0.1:4433";
                };
                advertised = true;
              };
              paseo = {
                endpoints = {
                  "tcp:6767" = "tcp://127.0.0.1:6767";
                };
              };
            }
          '';
        };
      };

      config = {
        services.tailscale = {
          disableUpstreamLogging = true;
          extraUpFlags = [ "--ssh" ];
          extraDaemonFlags = [ "--no-logs-no-support" ];
        };

        services.tailscale.serve.enable = true;

        # tailscaled-autoconnect (from nixpkgs tailscale module) has Type=notify
        # and waits for tailscale to reach "Running" state, which blocks the
        # login screen.
        #
        # Ordering alone doesn't help: greetd is Type=idle, so it waits until the
        # boot job queue is empty, and a pending notify start job keeps it busy.
        # Type=exec finishes the start job at exec; NotifyAccess=all keeps
        # NOTIFY_SOCKET set so the script's `systemd-notify --ready` doesn't fail.
        #
        # https://github.com/NixOS/nixpkgs/issues/430756
        systemd.services.tailscaled-autoconnect.serviceConfig = {
          Type = lib.mkForce "exec";
          NotifyAccess = "all";
        };

        systemd.services.tailscale-serve =
          lib.mkIf (config.services.tailscale.enable && cfg.enable && hasServices)
            {
              description = "Tailscale serve proxy service";
              wantedBy = [ "network-online.target" ];
              after = [
                "network-online.target"
                "tailscaled.service"
              ];
              wants = [
                "network-online.target"
                "tailscaled.service"
              ];
              partOf = [ "tailscaled.service" ];
              enableStrictShellChecks = true;
              serviceConfig = {
                RemainAfterExit = true;
                Restart = "on-failure";
                RestartSec = "2s";
                ExecStop = "${lib.getExe pkgs.tailscale} serve reset";
              };
              script = "${tailscaleServeScript}/bin/tailscale-serve";
            };
      };
    };
}
