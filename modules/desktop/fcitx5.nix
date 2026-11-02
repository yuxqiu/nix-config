let
  # NOTE: home-manager's i18n.inputMethod always installs a GTK2 immodule
  # cache, and nixpkgs now refuses to evaluate gtk2 (NixOS/nixpkgs#410814).
  # This replaces that module with a copy that installs only the GTK3 cache.
  # Drop once upstream gates gtk2 (the NixOS module already has `enableGtk2`).
  inputMethodWithoutGtk2 =
    {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    let
      cfg = config.i18n.inputMethod;
      upstreamFile = "${modulesPath}/i18n/input-method/default.nix";
      upstream = builtins.readFile upstreamFile;
      upstreamFixed = lib.hasInfix "enableGtk2" upstream || !lib.hasInfix "pkgs.gtk2" upstream;
    in
    {
      disabledModules = [ "i18n/input-method/default.nix" ];
      imports = map (m: "${modulesPath}/i18n/input-method/${m}.nix") [
        "fcitx5"
        "hime"
        "kime"
        "nabi"
        "uim"
      ];

      options.i18n.inputMethod = {
        enable = lib.mkEnableOption "an additional input method type";
        type = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "fcitx5"
              "nabi"
              "uim"
              "hime"
              "kime"
            ]
          );
          default = null;
        };
        package = lib.mkOption {
          internal = true;
          type = lib.types.nullOr lib.types.path;
          default = null;
        };
      };

      config = lib.mkIf cfg.enable {
        warnings = lib.optional upstreamFixed ''
          home-manager's ${upstreamFile} no longer installs gtk2 unconditionally.
          Remove `inputMethodWithoutGtk2` from modules/desktop/fcitx5.nix and use upstream.
        '';

        home.packages = [
          cfg.package
          (pkgs.runCommandLocal "gtk3-immodule.cache"
            {
              buildInputs = [
                pkgs.gtk3
                cfg.package
              ];
            }
            ''
              mkdir -p $out/etc/gtk-3.0/
              GTK_PATH=${cfg.package}/lib/gtk-3.0/ \
                gtk-query-immodules-3.0 > $out/etc/gtk-3.0/immodules.cache
            ''
          )
        ];
      };
    };
in
{
  flake.modules.homeManager.fcitx5 =
    { pkgs, ... }:
    {
      imports = [ inputMethodWithoutGtk2 ];

      # Inspired by:
      # - https://github.com/dcunited001/ellipsis/blob/02b014b561cfe1a9e6a00e8903e694c23ebc32bf/nixos/hosts/kratos/fcitx5.nix
      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5 = {
          addons = with pkgs; [
            # For Chinese input (includes libpinyin, cloudpinyin, etc.)
            qt6Packages.fcitx5-chinese-addons

            # Chinese dictionary
            fcitx5-pinyin-zhwiki

            # Rounded-corner classic-ui theme
            fcitx5-mellow-themes

            # Optional: GTK support for better integration in GTK apps
            fcitx5-gtk

            qt6Packages.fcitx5-configtool
          ];

          # Optional: If you're on Wayland, enable this to use the Wayland frontend
          waylandFrontend = true;

          # Optional: Declarative settings (example for basic input group setup)
          settings = {
            globalOptions = {
              Behavior = {
                ActiveByDefault = false;
              };
              Hotkey = {
                EnumerateWithTriggerKeys = true;
                EnumerateSkipFirst = false;
                ModifierOnlyKeyTimeout = 250;
              };
              "Hotkey/TriggerKeys" = {
                "0" = "Shift_L";
              };
              "Behavior/DisabledAddons" = {
                "0" = "clipboard";
                # KDE/plasma only
                "1" = "kimpanel";
                "2" = "quickphrase";
                "3" = "cloudpinyin";
                # Disable spell completion (English)
                "4" = "spell";
              };
            };
            addons = {
              classicui.globalSection.Theme = "mellow-graphite-dark";
              pinyin.globalSection.EmojiEnabled = "True";

              keyboard = {
                globalSection = {
                  # Disable the hint mode toggle (Ctrl+Alt+H/J)
                  "Hint Trigger" = "";
                  "One Time Hint Trigger" = "";
                };
              };
            };
            inputMethod = {
              GroupOrder = {
                "0" = "Default";
              };
              "Groups/0" = {
                Name = "Default";
                "Default Layout" = "us";
                DefaultIM = "keyboard-us"; # Default to English
              };
              # Add English, Chinese (Pinyin) to the group
              "Groups/0/Items/0" = {
                Name = "keyboard-us";
              };
              "Groups/0/Items/1" = {
                Name = "pinyin";
              }; # From fcitx5-chinese-addons
            };
          };
        };
      };

      stylix.targets.fcitx5.enable = false;
    };
}
