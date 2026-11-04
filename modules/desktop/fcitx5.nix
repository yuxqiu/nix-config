{
  flake.modules.homeManager.fcitx5 =
    { pkgs, ... }:
    {
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
