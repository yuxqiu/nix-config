let
  # false leaves the Xray client and `t2p` out of cedrus.
  enabled = false;
in
{
  flake.modules.nixos.cedrus =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      xray = config.services.xray.package;

      tunName = "xray0";
      # 198.18.0.0/15 is the RFC 2544 benchmarking range: never routed on the
      # internet and outside Docker's default address pools. The fake-IP pool
      # takes the lower /16, the TUN link a /30 in the upper /16.
      fakeIpPool = "198.18.0.0/16";
      tunGateway = "198.19.0.1/30";
      # The kernel owns the gateway address (.1); packets to any other address
      # in the TUN subnet reach Xray, which answers DNS through `dns-out`.
      tunDns = "198.19.0.2";

      # Merged after the sops config. Xray's multi-file rules: inbounds and
      # outbounds merge by tag, but a later file's `dns` and `routing` replace
      # the earlier ones whole, so those stay in the sops config: `fakedns`
      # first in `dns.servers`, and a first routing rule sending
      # `inboundTag = [ "tun" ]`, `port = 53` to `dns-out`. The file name must
      # contain "tail" so `dns-out` is appended instead of becoming the
      # default outbound.
      tunConfig = pkgs.writeTextFile {
        name = "xray-tun-tail.json";
        text = builtins.toJSON {
          # FakeDNS keeps a domain's fake IP until `poolSize` newer domains
          # evict it (LRU), not for a fixed time. 65535 fits in the /16.
          fakedns = [
            {
              ipPool = fakeIpPool;
              poolSize = 65535;
            }
          ];
          inbounds = [
            {
              tag = "tun";
              protocol = "tun";
              settings = {
                name = tunName;
                gateway = [ tunGateway ];
                # Binds outbounds to the physical interface so Xray's own
                # traffic skips the TUN routes `t2p` adds.
                autoOutboundsInterface = "auto";
              };
              sniffing = {
                enabled = true;
                destOverride = [ "fakedns" ];
              };
            }
          ];
          outbounds = [
            {
              tag = "dns-out";
              protocol = "dns";
            }
          ];
        };
        checkPhase = ''
          ${xray}/bin/xray run -test -c $out
        '';
      };

      t2p = pkgs.writeShellApplication {
        name = "t2p";

        runtimeInputs = with pkgs; [
          iproute2
          coreutils
          systemd
        ];

        text = ''
          TUN_IF="${tunName}"
          TUN_DNS="${tunDns}"
          # Present while the proxy is on. /run is cleared at boot, so the
          # proxy starts off, like the tunnel process it replaces.
          STATE_DIR="/run/t2p"
          STATE="$STATE_DIR/on"
          DOMAIN_CONF="/etc/systemd/resolved.conf.d/domain.conf"
          # Halves of each address family: more specific than any default
          # route, so they win without touching it.
          ROUTES=("0.0.0.0/1" "128.0.0.0/1" "::/1" "8000::/1")

          require_tun() {
              # Xray creates the TUN during startup, well within this bound.
              local tries=50
              until ip link show "$TUN_IF" >/dev/null 2>&1; do
                  if (( --tries == 0 )); then
                      echo "ERROR: $TUN_IF missing; is xray.service running?" >&2
                      exit 1
                  fi
                  sleep 0.1
              done
          }

          # Routes and per-link DNS live on the TUN link, so they vanish when
          # Xray restarts; xray.service reapplies them via `t2p resume`.
          apply() {
              require_tun
              local route
              for route in "''${ROUTES[@]}"; do
                  ip route replace "$route" dev "$TUN_IF"
              done
              resolvectl dns "$TUN_IF" "$TUN_DNS"
              resolvectl domain "$TUN_IF" "~."
              resolvectl flush-caches
          }

          on() {
              require_tun
              mkdir -p "$STATE_DIR"
              touch "$STATE"
              if [[ -f "$DOMAIN_CONF" ]]; then
                  rm -f "$DOMAIN_CONF"
                  systemctl restart systemd-resolved
              fi
              apply
              echo "on"
          }

          off() {
              rm -f "$STATE"
              local route
              for route in "''${ROUTES[@]}"; do
                  ip route del "$route" dev "$TUN_IF" 2>/dev/null || true
              done
              resolvectl revert "$TUN_IF" 2>/dev/null || true
              systemctl restart systemd-resolved-domain-conf
              systemctl restart systemd-resolved
              resolvectl flush-caches
              echo "off"
          }

          case "''${1:-}" in
            toggle) if [[ -e "$STATE" ]]; then off; else on; fi ;;
            status) if [[ -e "$STATE" ]]; then echo on; else echo off; fi ;;
            resume) if [[ -e "$STATE" ]]; then apply; fi ;;
            *) echo "Usage: $(basename "$0") {toggle|status|resume}" >&2; exit 1 ;;
          esac
        '';
      };

    in
    {
      config = lib.mkIf enabled {
        sops.secrets."xray.json" = {
          restartUnits = [ "xray.service" ];
        };

        services.xray = {
          enable = true;
          settingsFile = config.sops.secrets."xray.json".path;
        };

        systemd.services.xray = {
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          unitConfig.ConditionPathExists = config.sops.secrets."xray.json".path;
          serviceConfig = {
            ExecStart = lib.mkForce "${xray}/bin/xray run -config \"\${CREDENTIALS_DIRECTORY}\"/config.json -config ${tunConfig}";
            # `+`: runs as root; the service itself is a DynamicUser.
            ExecStartPost = "+${t2p}/bin/t2p resume";
          };
        };

        networking.firewall.trustedInterfaces = [ tunName ];
        networking.firewall.checkReversePath = "loose";

        environment.systemPackages = [ t2p ];
      };
    };
}
