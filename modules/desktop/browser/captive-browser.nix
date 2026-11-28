{
  flake.modules.homeManager.captive-browser =
    { pkgs, ... }:
    let
      # captive-browser's SOCKS5 proxy, which resolves names through the
      # DHCP-provided DNS server; the profile below sends all traffic to it.
      socksHost = "localhost";
      socksPort = 1666;
    in
    {
      home.packages = with pkgs; [ captive-browser ];
      home.file.".config/captive-browser.toml".source =
        (pkgs.formats.toml { }).generate "captive-browser.toml"
          {
            # Run with /bin/sh. Firefox honours the profile's empty
            # services.settings.server on release builds only when
            # MOZ_REMOTE_SETTINGS_DEVTOOLS=1 (services/settings/Utils.sys.mjs,
            # allowServerURL); otherwise it ignores the pref and keeps fetching
            # remote settings.
            browser = ''MOZ_REMOTE_SETTINGS_DEVTOOLS=1 exec firefox -P captive-browser --no-remote --private-window "http://neverssl.com/"'';
            # Shell command printing the DHCP DNS server; captive-browser uses the
            # first IPv4 address in its output.
            dhcp-dns = "nmcli dev show | grep IP4.DNS";
            socks5-addr = "${socksHost}:${toString socksPort}";
          };

      programs.firefox.profiles."captive-browser" = {
        id = 1;

        # Hide the tab strip: the portal page is the only tab.
        userChrome = ''
          #TabsToolbar { display: none; }
        '';

        settings = {
          # Send everything, DNS included, through captive-browser's proxy.
          "network.proxy.type" = 1;
          "network.proxy.socks_remote_dns" = true;
          "network.proxy.socks_version" = 5;
          "network.proxy.socks" = socksHost;
          "network.proxy.socks_port" = socksPort;
          "network.proxy.no_proxies_on" = "localhost, 127.0.0.1, [::1]";
          # Portals redirect plain HTTP and resolve through the DHCP DNS server.
          "dom.security.https_only_mode" = false;
          "network.trr.mode" = 5;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

          # Keep nothing from portal sessions on disk.
          "browser.cache.disk.enable" = false;
          "browser.cache.disk_cache_ssl" = false;
          "browser.cache.offline.enable" = false;
          "pdfjs.disabled" = true;

          # No background requests besides the portal's own.
          "extensions.pocket.enabled" = false;
          "extensions.pocket.onSaveRecs" = false;
          "browser.topsites.contile.enabled" = false;
          "browser.newtabpage.enabled" = false;
          "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
          "browser.newtabpage.activity-stream.discoverystream.enabled" = false;
          "browser.newtabpage.activity-stream.feeds.snippets" = false;
          "browser.newtabpage.activity-stream.feeds.system.topstories" = false;
          "browser.newtabpage.activity-stream.feeds.system.topsites" = false;
          "browser.newtabpage.activity-stream.feeds.systemtick" = false;
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.aboutHomeSnippets.updateUrl" = "";
          "browser.messaging-system.whatsNewPanel.enabled" = false;
          "browser.startup.homepage_override.mstone" = "ignore";
          "browser.ping-centre.telemetry" = false;
          "browser.region.update.enabled" = false;
          "browser.search.update" = false;
          "browser.search.geoip.url" = "";
          "geo.enabled" = false;
          "geo.provider.network.url" = "";
          "browser.region.network.url" = "";
          "geo.provider.use_geoclue" = false;
          "browser.uitour.enabled" = false;
          "browser.vpn_promo.enabled" = false;
          "datareporting.healthreport.uploadEnabled" = false;
          "datareporting.policy.dataSubmissionEnabled" = false;
          "media.gmp-gmpopenh264.enabled" = false;
          "media.gmp-manager.url" = "";
          "extensions.getAddons.cache.enabled" = false;
          "extensions.blocklist.enabled" = false;
          "extensions.systemAddon.update.enabled" = false;
          "extensions.systemAddon.update.url" = "";
          "app.update.auto" = false;
          "privacy.trackingprotection.enabled" = false;
          "privacy.trackingprotection.pbmode.enabled" = false;
          "privacy.trackingprotection.cryptomining.enabled" = false;
          "privacy.trackingprotection.emailtracking.enabled" = false;
          "privacy.trackingprotection.fingerprinting.enabled" = false;
          "privacy.trackingprotection.origin_telemetry.enabled" = false;
          "privacy.trackingprotection.socialtracking.enabled" = false;
          "services.settings.server" = "";
          "app.normandy.enabled" = false;
          "app.shield.optoutstudies.enabled" = false;
          "messaging-system.rsexperimentloader.enabled" = false;
          "toolkit.coverage.opt-out" = true;
          "toolkit.telemetry.coverage.opt-out" = true;
          "beacon.enabled" = false;
          "security.OCSP.enabled" = 0;
          "browser.discovery.enabled" = false;
          "network.captive-portal-service.enabled" = false;
          "network.connectivity-service.enabled" = false;
          "browser.safebrowsing.provider.mozilla.gethashURL" = "";
          "browser.safebrowsing.provider.mozilla.updateURL" = "";
          "browser.safebrowsing.malware.enabled" = false;
          "browser.safebrowsing.phishing.enabled" = false;
          "browser.safebrowsing.downloads.enabled" = false;
          "browser.safebrowsing.downloads.remote.enabled" = false;
          "browser.safebrowsing.downloads.remote.block_potentially_unwanted" = false;
          "browser.safebrowsing.downloads.remote.block_uncommon" = false;
          "browser.safebrowsing.blockedURIs.enabled" = false;
          "browser.safebrowsing.passwords.enabled" = false;
          "network.prefetch-next" = false;
          "network.dns.disablePrefetch" = true;
          "network.http.speculative-parallel-limit" = 0;
          "network.predictor.enabled" = false;
          "dom.push.enabled" = false;
        };
      };
    };
}
