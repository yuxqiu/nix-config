# t2p {toggle|status|resume}: sends all traffic through Xray's TUN inbound
# (routes and per-link DNS on the TUN link) or takes it back off. Run as root.
# `passthru.tun` holds the TUN addressing t2p expects, for the Xray config
# that creates the TUN to use the same values.
{
  writeShellApplication,
  iproute2,
  coreutils,
  systemd,
  # The resolved drop-in holding the global search domain, which t2p removes
  # while on. Hosts pass services.resolved.globalDomainConf (dns.nix), which
  # writes it; this default is the same path for a standalone build.
  domainConf ? "/etc/systemd/resolved.conf.d/domain.conf",
}:
let
  # 198.18.0.0/15 is the RFC 2544 benchmarking range: never routed on the
  # internet and outside Docker's default address pools. The fake-IP pool
  # takes the lower /16, the TUN link a /30 in the upper /16.
  tun = {
    interface = "xray0";
    fakeIpPool = "198.18.0.0/16";
    gateway = "198.19.0.1/30";
    # The kernel owns the gateway address (.1); packets to any other address
    # in the TUN subnet reach Xray, which answers DNS through `dns-out`.
    dns = "198.19.0.2";
  };
in
writeShellApplication {
  name = "t2p";

  passthru = { inherit tun; };

  runtimeInputs = [
    iproute2
    coreutils
    systemd
  ];

  text = ''
    TUN_IF="${tun.interface}"
    TUN_DNS="${tun.dns}"
    # Present while the proxy is on. /run is cleared at boot, so the
    # proxy starts off, like the tunnel process it replaces.
    STATE_DIR="/run/t2p"
    STATE="$STATE_DIR/on"
    DOMAIN_CONF="${domainConf}"
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
}
