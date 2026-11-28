{
  flake.modules.homeManager.firefox =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      profileName = "default";

      # Reads a stylesheet and fills in its @placeholders@; each one given must
      # appear in the file.
      cssWithSubstitutions =
        file: substitutions:
        let
          css = builtins.readFile file;
        in
        assert lib.all (
          placeholder:
          lib.assertMsg (lib.hasInfix placeholder css) "firefox.nix: ${placeholder} placeholder missing from ${baseNameOf file}"
        ) (lib.attrNames substitutions);
        builtins.replaceStrings (lib.attrNames substitutions) (lib.attrValues substitutions) css;

      # Menus and the search popup are tinted with stylix's popup opacity, like
      # GTK and Qt menus.
      popupOpacity = toString config.lib.style.popupOpacityPercent;
      # The menu corner radius is shared with niri's `popups` blur rule below;
      # 6 is Firefox's default menupopup --panel-border-radius.
      popupRadius = 6;
      menupopup = cssWithSubstitutions ./css/chrome/menupopup.css {
        "@popupOpacity@" = popupOpacity;
        "@popupRadius@" = toString popupRadius;
      };
      search = cssWithSubstitutions ./css/chrome/search.css { "@popupOpacity@" = popupOpacity; };

      # --device-pixel: one device pixel in CSS px, for CSS that must land on
      # the device pixel grid. Gecko lays out in 60 app units per CSS px and
      # rounds the app units per device pixel to an integer N, so
      # devicePixelRatio is 60/N (60/34 at a 1.75 output scale) and a device
      # pixel is N/60 CSS px (nsDeviceContext::SetDPI). userChrome can't use
      # Firefox's env(hairline) and CSS can't invert `resolution`, so each N
      # gets a media range around 60/N, halfway to its neighbours. N from 15
      # to 120 covers scales 4 to 0.5.
      devicePixelCss = lib.concatMapStrings (n: ''
        @media (min-resolution: ${toString (60.0 / (n + 0.5))}dppx) and (max-resolution: ${toString (60.0 / (n - 0.5))}dppx) {
          :root { --device-pixel: calc(${toString n}px / 60); }
        }
      '') (lib.range 15 120);

      # Prepare user.js
      arkenfoxUserJs = builtins.readFile "${
        pkgs.fetchFromGitHub {
          owner = "arkenfox";
          repo = "user.js";
          rev = "144.0";
          hash = "sha256-oo3/j53+vDh0Y+uCMPFUGEc4bDr7uD4CzagEuQX5PM8=";
        }
      }/user.js";

      firefox-mod-blur = pkgs.fetchFromGitHub {
        owner = "datguypiko";
        repo = "Firefox-Mod-Blur";
        rev = "v2.80";
        hash = "sha256-z0DhpbfTcy51Ec+n3HuPyBrZ6n35HluPrMuGBs9FJyo=";
      };

      # Prepare userChrome.css
      userChrome = builtins.concatStringsSep "\n" [
        (builtins.readFile ./css/chrome/tokens.css)
        devicePixelCss
        (builtins.readFile ./css/chrome/blur.css)
        (builtins.readFile ./css/chrome/container.css)
        (builtins.readFile ./css/chrome/control.css)
        (builtins.readFile ./css/chrome/findbar.css)
        (builtins.readFile ./css/chrome/liquid-fox.css)
        menupopup
        search
        (builtins.readFile "${firefox-mod-blur}/EXTRA MODS/Privacy mods/Blur Username in main menu/privacy_blur_email_in_main_menu.css")
        (builtins.readFile "${firefox-mod-blur}/EXTRA MODS/Compact extensions menu/Style 1/With no settings wheel icon/cleaner_extensions_menu.css")
        (builtins.readFile "${firefox-mod-blur}/EXTRA MODS/Icon and Button Mods/uBlock icon change/ublock-icon-change.css")
        (builtins.readFile "${firefox-mod-blur}/EXTRA MODS/Search Bar Mods/Search box - no border/url_bar_no_border.css")
        (builtins.readFile "${firefox-mod-blur}/EXTRA MODS/Icon and Button Mods/Icons in main menu/icons_in_main_menu.css")
        (builtins.readFile "${firefox-mod-blur}/EXTRA MODS/Tabs Bar Mods/Colored sound playing tab/colored_soundplaying_tab.css")
      ];

      # Prepare userContent.css
      userContent = builtins.concatStringsSep "\n" [
        (builtins.readFile ./css/content/home.css)
        (builtins.readFile "${firefox-mod-blur}/EXTRA MODS/Homepage mods/Remove text from homepage shortcuts/remove_homepage_shortcut_title_text.css")
      ];

    in
    {
      persistence.directories = [ ".config/mozilla" ];
      # Enable Firefox and define profiles
      programs.firefox = {
        enable = true;
        profiles.${profileName} = {
          isDefault = true;

          extensions = {
            force = true;
          };

          # user.js (overrides live in ./prefs.nix)
          preConfig = arkenfoxUserJs;

          # userChrome and userContent
          inherit userChrome;
          inherit userContent;
        };
        policies = {
          AutofillAddressEnabled = false;
          AutofillCreditCardEnabled = false;
          CaptivePortal = false;
          DisableFirefoxStudies = true;
          DisablePocket = true;
          DisableTelemetry = true;
          DisableFirefoxAccounts = false;
          DisableFormHistory = true;
          DisableMasterPasswordCreation = true;
          DisableProfileImport = true;
          DisableFeedbackCommands = true;
          DisableFirefoxScreenshots = true;
          DisableSetDesktopBackground = true;
          DontCheckDefaultBrowser = true;
          ExtensionUpdate = false;
          FirefoxHome = {
            Search = true;
            Pocket = false;
            Snippets = false;
            TopSites = false;
            SponsoredTopSites = false;
            Highlights = false;
            SponsoredPocket = false;
          };
          FirefoxSuggest = {
            WebSuggestions = false;
            SponsoredSuggestions = false;
            ImproveSuggest = false;
          };
          NoDefaultBookmarks = true;
          OfferToSaveLogins = false;
          OfferToSaveLoginsDefault = false;
          OverrideFirstRunPage = "";
          OverridePostUpdatePage = "";
          PasswordManagerEnabled = false;
          SearchEngines = {
            Remove = [
              "Amazon.com"
              "Bing"
              "DuckDuckGo"
              "eBay"
              "Google"
              "Perplexity"
              "Wikipedia (en)"
            ];
            Add = [
              {
                Name = "ddg";
                URLTemplate = "https://duckduckgo.com/?q={searchTerms}";
                IconURL = "https://duckduckgo.com/favicon.ico";
                Alias = "ddg";
              }
              {
                Name = "google";
                URLTemplate = "https://www.google.com/search?q={searchTerms}";
                IconURL = "https://www.gstatic.com/images/branding/searchlogo/ico/favicon.ico";
                Alias = "goo";
              }
            ];
          };
          SkipTermsOfUse = true;
          UserMessaging = {
            WhatsNew = false;
            ExtensionRecommendations = false;
            FeatureRecommendations = false;
            UrlbarInterventions = false;
            SkipOnboarding = true;
            MoreFromMozilla = false;
          };

          ExtensionSettings = {
            "uBlock0@raymondhill.net" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
              installation_mode = "normal_installed";
              default_area = "navbar";
            };
          };
          "3rdparty".Extensions = {
            # https://github.com/gorhill/uBlock/blob/master/platform/common/managed_storage.json
            "uBlock0@raymondhill.net" = {
              userSettings = [
                [
                  "cloudStorageEnabled"
                  "false"
                ]
                [
                  "contextMenuEnabled"
                  "false"
                ]
                [
                  "showIconBadge"
                  "false"
                ]
              ];
              toOverwrite = {
                filterLists = [
                  "user-filters"
                  "ublock-filters"
                  "ublock-badware"
                  "ublock-privacy"
                  "ublock-quick-fixes"
                  "ublock-unbreak"
                  "easyprivacy"
                  "adguard-spyware-url"
                  "block-lan"
                  "plowe-0"
                  "ublock-cookies-adguard"
                  "ublock-annoyances"
                ];
                filters = [
                  # ! disable the funky gradient at the bottom of Youtube player due to RFP
                  "www.youtube.com##.ytp-gradient-bottom"

                  # ! https://www.reddit.com/r/firefox/comments/1digcp4/comment/l93oijg/
                  "$3p,to=facebook.*|instagram.com,from=~facebook.*|~instagram.com|~messenger.com|~threads.net"

                  # ! https://old.reddit.com/r/firefox/comments/1defcc2/new_to_mozilla_firefox_coming_from_brave_browser/l8f83y9/?context=2
                  # ! block all 3p frames
                  "$3p,frame"

                  # ! allow Cloudflare security challenge iframes
                  "@@||challenges.cloudflare.com^$3p,frame"

                  # ! show "click to play" placeholders for all blocked frames
                  "$3p,frame,redirect-rule=click2load.html"
                ];
              };
            };
          };
        };
      };

      # stylix
      stylix.targets.firefox.profileNames = [ profileName ];

      xdg.mimeApps = {
        associations.added = {
          "text/html" = [ "firefox.desktop" ];
          "x-scheme-handler/http" = [ "firefox.desktop" ];
          "x-scheme-handler/https" = [ "firefox.desktop" ];
        };

        defaultApplications = {
          "text/html" = [ "firefox.desktop" ];
          "x-scheme-handler/http" = [ "firefox.desktop" ];
          "x-scheme-handler/https" = [ "firefox.desktop" ];
        };
      };

      wayland.windowManager.niri.settings._children = lib.mkAfter [
        {
          window-rule = {
            match._props."app-id" = "firefox";
            background-effect.blur = true;
            # the radius menupopup.css gives menus and arrow panels
            popups = {
              geometry-corner-radius = popupRadius;
              background-effect.blur = true;
            };
          };
        }

        {
          window-rule = {
            match._props = {
              "app-id" = "firefox$";
              title = "^Picture-in-Picture$";
            };
            open-floating = true;
          };
        }
      ];
    };
}
