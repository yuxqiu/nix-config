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
      inherit (inputs.self.packages.${pkgs.stdenv.hostPlatform.system}) dms-brightness;
      # argv of `dms ipc call <args>`, for niri's spawn.
      dmsIpcCall =
        args:
        [
          "dms"
          "ipc"
          "call"
        ]
        ++ args;
    in
    {
      persistence.directories = [
        ".local/state/dms"
        {
          directory = ".local/share/dankcal";
          mode = "0700";
        }
      ];
      imports = [
        inputs.dms.homeModules.dank-material-shell
        inputs.dms-plugin-registry.homeModules.default
        inputs.danksearch.homeModules.dsearch
      ];

      programs.dank-material-shell = {
        enable = true;
        systemd.enable = true;

        enableDynamicTheming = false;
        enableCalendarEvents = false;

        settings = builtins.fromJSON (builtins.readFile ./configs/settings.json) // {
          customThemeFile = "${inputs.dms-plugin-registry}/themes/catppuccin/theme.json";
        };
      };

      programs.dsearch.enable = true;

      # Restart dms service when settings or plugins are changed
      systemd.user.services.dms.Unit.X-Restart-Triggers = [
        config.xdg.configFile."dms/settings.json".source
        config.xdg.configFile."dms/plugin_settings.json".source
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
              spawn = dmsIpcCall [
                "spotlight"
                "toggle"
              ];
            };

            "Mod+V" = {
              _props.hotkey-overlay-title = "Clipboard Manager";
              spawn = dmsIpcCall [
                "clipboard"
                "toggle"
              ];
            };

            "Mod+Slash" = {
              _props.hotkey-overlay-title = "Search Keybinds";
              spawn = dmsIpcCall [
                "spotlight"
                "toggleQuery"
                "\\"
              ];
            };

            "Mod+Shift+O" = {
              _props.hotkey-overlay-title = "Lock Screen";
              spawn = dmsIpcCall [
                "lock"
                "lock"
              ];
            };

            "XF86AudioRaiseVolume" = {
              _props."allow-when-locked" = true;
              spawn = dmsIpcCall [
                "audio"
                "increment"
                "5"
              ];
            };

            "XF86AudioLowerVolume" = {
              _props."allow-when-locked" = true;
              spawn = dmsIpcCall [
                "audio"
                "decrement"
                "5"
              ];
            };

            "XF86AudioMute" = {
              _props."allow-when-locked" = true;
              spawn = dmsIpcCall [
                "audio"
                "mute"
              ];
            };

            "XF86AudioMicMute" = {
              _props."allow-when-locked" = true;
              spawn = dmsIpcCall [
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
