{
  flake.modules.nixos.dns =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      dnscrypt-resolvers = pkgs.fetchFromGitHub {
        owner = "DNSCrypt";
        repo = "dnscrypt-resolvers";
        rev = "be83948783d10ace1febef4180d640936acd40ea"; # follow:branch master
        hash = "sha256-+8F5i+oVrKWoeLhhGlrbX3eFGXJKeO1jz0dCEc49xCo=";
      };
      # Key the dnscrypt-resolvers lists are signed with (published in that
      # repo's README).
      resolversMinisignKey = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
      domainConf = config.services.resolved.globalDomainConf;
    in
    {
      options.services.resolved.globalDomainConf = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "/etc/systemd/resolved.conf.d/domain.conf";
        description = ''
          resolved drop-in that routes every domain (`Domains=~.`) to the global
          DNS server. Written at boot by systemd-resolved-domain-conf.service
          rather than through environment.etc: a proxy that routes DNS through
          its own link deletes it while active and restarts that unit to put
          it back, which a read-only store symlink would not allow.
        '';
      };

      config = {
        services.resolved.enable = true;

        # Writes the domain drop-in before resolved starts.
        systemd.services.systemd-resolved-domain-conf = {
          description = "Create global DNS domain override for systemd-resolved";
          # resolved is ordered before sysinit.target (DefaultDependencies=no);
          # default deps here (After=basic.target) would form an ordering cycle.
          unitConfig.DefaultDependencies = false;
          after = [ "local-fs.target" ];
          before = [ "systemd-resolved.service" ];
          wantedBy = [ "systemd-resolved.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = pkgs.writeShellScript "systemd-resolved-domain-setup" ''
              set -euo pipefail

              ${pkgs.coreutils}/bin/mkdir -p ${dirOf domainConf}
              ${pkgs.coreutils}/bin/printf "[Resolve]\\nDomains=~.\\n" > ${domainConf}
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
              minisign_key = resolversMinisignKey;
            };

            sources.relays = {
              cache_file = "${dnscrypt-resolvers}/v3/relays.md";
              minisign_key = resolversMinisignKey;
            };

            sources.odoh-servers = {
              cache_file = "${dnscrypt-resolvers}/v3/odoh-servers.md";
              minisign_key = resolversMinisignKey;
            };

            sources.odoh-relays = {
              cache_file = "${dnscrypt-resolvers}/v3/odoh-relays.md";
              minisign_key = resolversMinisignKey;
            };

            server_names = [
              "odoh-cloudflare"
              "odoh-snowstorm"
              # Fallbacks when the ODoH servers are unreachable
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

        services.resolved.settings.Resolve = {
          DNS = "127.0.0.1";
          FallbackDNS = "";
        };
      };
    };
}
