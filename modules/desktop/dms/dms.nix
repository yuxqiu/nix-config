{
  inputs,
  ...
}:
{
  flake.modules.homeManager.dms =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      niri-focused-output = pkgs.callPackage (inputs.self + /packages/niri-focused-output.nix) { };
      dms-brightness = pkgs.callPackage (inputs.self + /packages/dms-brightness.nix) {
        inherit niri-focused-output;
      };
    in
    {
      imports = [
        inputs.dms.homeModules.dank-material-shell
        inputs.dms-plugin-registry.homeModules.default
        inputs.danksearch.homeModules.dsearch
        inputs.dankcalendar.homeModules.dank-calendar
      ];

      programs.dank-material-shell = {
        enable = true;
        systemd = {
          enable = true;
          restartIfChanged = true;
        };

        enableSystemMonitoring = true;
        enableVPN = true;
        enableDynamicTheming = false;
        enableAudioWavelength = true;
        enableCalendarEvents = false;
        enableClipboardPaste = true;

        settings = builtins.fromJSON (builtins.readFile ./configs/settings.json) // {
          customThemeFile = "${inputs.dms-plugin-registry}/themes/catppuccin/theme.json";
        };
      };

      programs.dank-calendar = {
        enable = true;
        systemd.enable = true;
      };

      programs.dsearch.enable = true;

      # Restart dms service when settings or plugins are changed
      systemd.user.services.dms.Unit.X-Restart-Triggers = [
        config.xdg.configFile."DankMaterialShell/settings.json".source
        config.xdg.configFile."DankMaterialShell/plugin_settings.json".source
      ]
      ++ lib.mapAttrsToList (_: plugin: plugin.src) (
        lib.filterAttrs (_: plugin: plugin.enable) config.programs.dank-material-shell.plugins
      );

      wayland.windowManager.niri = {
        settings = {
          config-notification.disable-failed = [ ];

          # Show wallpaper on desktop and overview.
          layout.background-color = "transparent";

          _children = lib.mkMerge [
            (lib.mkAfter [
              {
                layer-rule = {
                  match._props.namespace = "^quickshell$";
                  place-within-backdrop = true;
                };
              }
            ])

            # The bar reserves its space, so only wallpaper sits under it;
            # non-xray blur would just bleed in adjacent windows. The dock is
            # left out: with auto-hide it reserves nothing and overlaps windows.
            # Ordered after the top/overlay xray=false rule in
            # niri/configs/blur.nix (mkAfter = 1500) so this one wins.
            (lib.mkOrder 1600 [
              {
                layer-rule = {
                  match._props.namespace = "^dms:(bar|dankisland)$";
                  background-effect.xray = true;
                };
              }
            ])
          ];

          overview.workspace-shadow.off = [ ];

          binds = {
            "Mod+Space" = {
              _props.hotkey-overlay-title = "Application Launcher";
              spawn = [
                "dms"
                "ipc"
                "call"
                "spotlight"
                "toggle"
              ];
            };

            "Mod+V" = {
              _props.hotkey-overlay-title = "Clipboard Manager";
              spawn = [
                "dms"
                "ipc"
                "call"
                "clipboard"
                "toggle"
              ];
            };

            "Mod+Slash" = {
              _props.hotkey-overlay-title = "Search Keybinds";
              spawn = [
                "dms"
                "ipc"
                "call"
                "spotlight"
                "toggleQuery"
                "\\"
              ];
            };

            "Mod+Shift+O" = {
              _props.hotkey-overlay-title = "Lock Screen";
              spawn = [
                "dms"
                "ipc"
                "call"
                "lock"
                "lock"
              ];
            };

            "XF86AudioRaiseVolume" = {
              _props."allow-when-locked" = true;
              spawn = [
                "dms"
                "ipc"
                "call"
                "audio"
                "increment"
                "5"
              ];
            };

            "XF86AudioLowerVolume" = {
              _props."allow-when-locked" = true;
              spawn = [
                "dms"
                "ipc"
                "call"
                "audio"
                "decrement"
                "5"
              ];
            };

            "XF86AudioMute" = {
              _props."allow-when-locked" = true;
              spawn = [
                "dms"
                "ipc"
                "call"
                "audio"
                "mute"
              ];
            };

            "XF86AudioMicMute" = {
              _props."allow-when-locked" = true;
              spawn = [
                "dms"
                "ipc"
                "call"
                "audio"
                "micmute"
              ];
            };

            "XF86MonBrightnessUp" = {
              _props."allow-when-locked" = true;
              spawn-sh = "${dms-brightness}/bin/dms-brightness increment 5";
            };

            "XF86MonBrightnessDown" = {
              _props."allow-when-locked" = true;
              spawn-sh = "${dms-brightness}/bin/dms-brightness decrement 5";
            };
          };
        };
      };

      stylix.targets.dank-material-shell.enable = false;
    };
}
