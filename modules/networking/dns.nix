{
  flake.modules.nixos.dns =
    { pkgs, ... }:
    let
      dnscrypt-resolvers = pkgs.fetchFromGitHub {
        owner = "DNSCrypt";
        repo = "dnscrypt-resolvers";
        rev = "e070d8fabeac6b9760ffb9397b294a246494eb9a"; # follow:branch master
        hash = "sha256-geQ19eO4nh95ECTx42uCWQBMHXjxTtKK6gq8SSHh4fM=";
      };
    in
    {
      services.resolved.enable = true;

      # create resolved domain config before resolved starts
      systemd.services.systemd-resolved-domain-conf = {
        enable = true;
        description = "Create global DNS domain override for systemd-resolved";
        before = [ "systemd-resolved.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "systemd-resolved-domain-setup" ''
            set -euo pipefail

            ${pkgs.coreutils}/bin/mkdir -p /etc/systemd/resolved.conf.d
            ${pkgs.coreutils}/bin/printf "[Resolve]\\nDomains=~.\\n" > /etc/systemd/resolved.conf.d/domain.conf
          '';
          StandardOutput = "journal";
        };
      };

      services.dnscrypt-proxy = {
        enable = true;
        settings = {
          listen_addresses = [ "127.0.0.1:53" ];

          sources.public-resolvers = {
            cache_file = "${dnscrypt-resolvers}/v3/public-resolvers.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
          };

          sources.relays = {
            cache_file = "${dnscrypt-resolvers}/v3/relays.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
          };

          sources.odoh-servers = {
            cache_file = "${dnscrypt-resolvers}/v3/odoh-servers.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
          };

          sources.odoh-relays = {
            cache_file = "${dnscrypt-resolvers}/v3/odoh-relays.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
          };

          server_names = [
            "odoh-cloudflare"
            "odoh-snowstorm"
            # Workaround when odoh is not available
            "controld-unfiltered"
            "mullvad-doh"
          ];

          # This creates the [anonymized_dns] section in dnscrypt-proxy.toml
          anonymized_dns = {
            skip_incompatible = true;
            routes = [
              {
                server_name = "odoh-snowstorm";
                via = [ "odohrelay-crypto-sx" ];
              }
              {
                server_name = "odoh-cloudflare";
                via = [ "odohrelay-crypto-sx" ];
              }
            ];
          };

          require_dnssec = true;
          require_nolog = true;
          require_nofilter = true;
          odoh_servers = true;
          dnscrypt_servers = true;
        };
      };

      networking.nameservers = [
        "127.0.0.1"
        "::1"
      ];

      services.resolved.settings.Resolve = {
        DNS = "127.0.0.1";
        FallbackDNS = "";
      };
    };
}
