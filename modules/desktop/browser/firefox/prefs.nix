{
  flake.modules.homeManager.firefox = {
    # applied after arkenfox's user.js (preConfig), so these override it
    programs.firefox.profiles.default.settings = {
      # stylix: prevent auto disabling extensions installed inside firefox
      # https://github.com/nix-community/home-manager/issues/6398#issuecomment-2958982664
      "extensions.autoDisableScopes" = 0;
      "extensions.update.autoUpdateDefault" = false;
      "extensions.update.enabled" = false;

      # 0102: startup page: 0=blank, 1=home, 2=last visited page, 3=resume previous session
      "browser.startup.page" = 1;
      # 0103: homepage and new windows
      "browser.startup.homepage" = "about:home";
      # 0104: new tab page: true=Firefox Home, false=blank page
      "browser.newtabpage.enabled" = true;

      # 0401: disable SB (Safe Browsing) master switches
      "browser.safebrowsing.malware.enabled" = false;
      "browser.safebrowsing.phishing.enabled" = false;
      # 0402: disable SB checks for downloads (both local lookups + remote)
      "browser.safebrowsing.downloads.remote.enabled" = false;
      "browser.safebrowsing.downloads.remote.url" = ""; # defense-in-depth
      # 0404: disable SB checks for unwanted software
      "browser.safebrowsing.downloads.remote.block_potentially_unwanted" = false;
      "browser.safebrowsing.downloads.remote.block_uncommon" = false;
      # 0405: disable "ignore this warning" on SB warnings
      "browser.safebrowsing.allowOverride" = false;
      "browser.safebrowsing.blockedURIs.enabled" = false;

      # 0710: DoH: 0=off by default, 2=TRR first, 3=TRR only, 5=explicitly off
      "network.trr.mode" = 5;

      # 0801: allow location bar search
      "keyword.enabled" = true;

      # 1001: keep disk cache
      "browser.cache.disk.enable" = true;

      # 2002/2003: keep WebRTC stable behind proxy
      "media.peerconnection.ice.proxy_only_if_behind_proxy" = false;
      "media.peerconnection.ice.default_address_only" = false;

      # 4520: keep WebGL
      "webgl.disabled" = false;

      # email tracking: no data collection, enable protection
      "privacy.trackingprotection.emailtracking.data_collection.enabled" = false;
      "privacy.trackingprotection.emailtracking.enabled" = true;

      # allow macos native fullscreen
      "full-screen-api.macos-native-full-screen" = true;

      # disable all promos
      "browser.contentblocking.report.vpn-promo.url" = "";
      "browser.promo.pin.enabled" = false;
      "browser.vpn_promo.enabled" = false;
      "identity.mobilepromo.android" = "";
      "identity.mobilepromo.ios" = "";
      "identity.sendtabpromo.url" = "";

      # disable feature recommendation
      "browser.newtabpage.activity-stream.feeds.discoverystreamfeed" = false;

      # disable add-on metadata updating
      "extensions.getAddons.cache.enabled" = false;

      # disable auto submit crash report
      "browser.crashReports.unsubmittedCheck.enabled" = false;

      # disable "you haven't started Firefox in a while." message
      # https://support.mozilla.org/en-US/questions/1231948
      "browser.disableResetPrompt" = false;

      # disable default browser check
      "browser.shell.checkDefaultBrowser" = false;

      # disable health report
      "datareporting.healthreport.service.enabled" = false;

      # disable battery access
      "dom.battery.enabled" = false;

      # disable more telemetry
      "toolkit.telemetry.cachedClientID" = "";
      "toolkit.telemetry.cachedProfileGroupID" = "";

      # hide "More from Mozilla" in Settings
      "browser.preferences.moreFromMozilla" = false;

      # disable fullscreen delay and notice
      "full-screen-api.transition-duration.enter" = "0 0";
      "full-screen-api.transition-duration.leave" = "0 0";
      "full-screen-api.warning.delay" = -1;
      "full-screen-api.warning.timeout" = 0;

      # disable welcome notices
      "browser.aboutwelcome.enabled" = false;

      # open PDFs inline
      # [1] https://support.mozilla.org/en-US/questions/1387228
      "browser.download.open_pdf_attachments_inline" = true;

      # prevent password truncation when submitting form data
      # [1] https://www.ghacks.net/2020/05/18/firefox-77-wont-truncate-text-exceeding-max-length-to-address-password-pasting-issues/
      "editor.truncate_user_pastes" = false;

      # disable Form Autofill (stored data is not secure, uses a JSON file)
      # [1] https://wiki.mozilla.org/Firefox/Features/Form_Autofill
      "extensions.formautofill.addresses.enabled" = false;
      "extensions.formautofill.creditCards.enabled" = false;
      "browser.formfill.enable" = false;

      # software that continually reports what default browser you are using
      # [WARNING] Breaks "Make Default..." button in Preferences [1]
      # [1] https://github.com/yokoffing/Betterfox/issues/166
      "default-browser-agent.enabled" = false;

      # PDF sidebar on load: 2=table of contents (falls back to 1), 1=view pages, -1=disabled
      "pdfjs.sidebarViewOnLoad" = 2;

      # hide toolbar shown after pressing Alt
      "ui.key.menuAccessKeyFocuses" = false;

      # disable accessibility
      "accessibility.force_disabled" = 1;
      "devtools.accessibility.enabled" = false;
      "accessibility.typeaheadfind" = false;

      # don't close browser when last tab is closed
      "browser.tabs.closeWindowWithLastTab" = false;

      # Let's Encrypt starts to drop OCSP Support
      # Also, there are privacy concerns regarding OCSP
      "security.OCSP.enabled" = 0;
      "security.OCSP.require" = false;

      # disable region updates
      "browser.region.network.url" = "";
      "browser.region.update.enabled" = false;

      # disable fetch of safebrowsing updates
      "browser.safebrowsing.provider.google4.advisoryURL" = "";
      "browser.safebrowsing.provider.google4.dataSharingURL" = "";
      "browser.safebrowsing.provider.google4.gethashURL" = "";
      "browser.safebrowsing.provider.google4.updateURL" = "";
      "browser.safebrowsing.provider.google.advisoryURL" = "";
      "browser.safebrowsing.provider.google.gethashURL" = "";
      "browser.safebrowsing.provider.google.updateURL" = "";

      # disable reader mode
      "reader.parse-on-load.enabled" = false;

      # disable push notification connection
      "dom.push.connection.enabled" = false;
      "dom.push.serverURL" = "";

      # disable activity stream
      "browser.newtabpage.activity-stream.discoverystream.enabled" = false;

      # disable topsites
      "browser.topsites.contile.enabled" = false;
      "browser.topsites.contile.endpoint" = "";

      # disable geo location
      "geo.provider.network.url" = "";

      # enable RFP via FPP
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1732114
      "privacy.resistFingerprinting" = false;
      "privacy.fingerprintingProtection" = true;
      "privacy.fingerprintingProtection.overrides" = "+AllTargets,-CSSPrefersColorScheme";

      # prevent Firefox from adding back search engines after you removed them
      # [NOTE] does not affect Mozilla's built-in or Web Extension search engines
      "browser.search.update" = false;

      # purge session icon in Private Browsing windows
      "browser.privatebrowsing.resetPBM.enabled" = true;

      # prevent title bar hiding on fullscreen
      "browser.fullscreen.autohide" = false;

      # enable local network access permission management
      "network.lna.enabled" = true;
      "network.lna.blocking" = true;
      "network.lna.block_trackers" = true;

      # Webrender layer compositor (from FastFox)
      # [1] https://bugzilla.mozilla.org/show_bug.cgi?id=1945683
      # [2] https://www.reddit.com/r/firefox/comments/1p58qre/firefox_is_getting_ready_to_make_youtube_fast/
      # [3] https://www.ghacks.net/2025/11/24/these-two-tweaks-should-improve-firefoxs-performance-on-youtube-significantly/
      "gfx.webrender.layer-compositor" = true;

      # styling: legacy stylesheet support + custom stylings
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      "svg.context-properties.content.enabled" = true;
      "widget.gtk.rounded-bottom-corners.enabled" = true;
      "browser.toolbars.bookmarks.showOtherBookmarks" = false;
      "browser.toolbars.bookmarks.visibility" = "never";

      # vertical bar by default
      "sidebar.revamp" = true;
      "sidebar.verticalTabs" = true;

      # AI
      "browser.ai.control.default" = "blocked";
      "browser.ai.control.linkPreviewKeyPoints" = "blocked";
      "browser.ai.control.pdfjsAltText" = "blocked";
      "browser.ai.control.sidebarChatbot" = "blocked";
      "browser.ai.control.smartTabGroups" = "blocked";
      "browser.ai.control.translations" = "available";
      "browser.ml.chat.enabled" = false;
      "browser.ml.chat.page" = false;
      "browser.ml.linkPreview.collapsed" = true;
      "browser.ml.linkPreview.enabled" = false;
      "browser.ml.linkPreview.onboardingTimes" = "";

      # disable about:config warning
      "browser.aboutConfig.showWarning" = false;

      # open new tab next to the current one
      "browser.tabs.insertAfterCurrent" = true;

      # ip protection
      "browser.ipProtection.enabled" = true;
    };
  };
}
