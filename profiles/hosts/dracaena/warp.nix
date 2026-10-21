{
  flake.modules.nixos.dracaena = { pkgs, ... }: {
    services.cloudflare-warp.enable = true;

    # warp-svc only starts the daemon; registration + proxy mode are
    # `warp-cli` calls against it, not declarative options this module
    # exposes. Make that idempotent so it survives reboots/rebuilds cleanly.
    systemd.services.warp-setup = {
      description = "One-time Cloudflare WARP registration + proxy mode";
      after = [ "cloudflare-warp.service" ];
      requires = [ "cloudflare-warp.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.cloudflare-warp ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      script = ''
        set -euo pipefail
        for i in $(seq 1 30); do
          warp-cli --accept-tos status && break
          sleep 1
        done
        warp-cli --accept-tos registration show || warp-cli --accept-tos registration new
        warp-cli --accept-tos mode proxy
        warp-cli --accept-tos proxy port 40000
        warp-cli --accept-tos connect
      '';
    };
  };
}
