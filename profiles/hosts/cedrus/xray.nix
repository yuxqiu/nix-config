{ inputs, ... }:
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

      # The drop-in t2p removes and restores is the one dns.nix writes.
      t2p = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.t2p.override {
        domainConf = config.services.resolved.globalDomainConf;
      };
      inherit (t2p) tun;

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
              ipPool = tun.fakeIpPool;
              poolSize = 65535;
            }
          ];
          inbounds = [
            {
              tag = "tun";
              protocol = "tun";
              settings = {
                name = tun.interface;
                gateway = [ tun.gateway ];
                # Binds outbounds to the physical interface so Xray's own
                # traffic skips the TUN routes `t2p` adds.
                autoOutboundsInterface = "auto";
              };
              sniffing = {
                enabled = false;
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

        networking.firewall.trustedInterfaces = [ tun.interface ];
        networking.firewall.checkReversePath = "loose";

        environment.systemPackages = [ t2p ];
      };
    };
}
