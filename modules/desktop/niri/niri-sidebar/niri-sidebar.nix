{ inputs, ... }:
{
  flake.modules.homeManager.niri =
    { pkgs, lib, ... }:
    let
      niri-sidebar = pkgs.callPackage (inputs.self + /packages/niri-sidebar.nix) { };

      niri-sidebar-config = pkgs.writeText "config.toml" ''
        [geometry]
        width = 550
        height = 335
        gap = 15

        [margins]
        top = 30
        right = 20
        bottom = 50

        [interaction]
        position = "right"
        peek = 70
        focus_peek = 70
        sticky = false
      '';

      configDir = pkgs.runCommand "niri-sidebar-xdg-config" { } ''
        mkdir -p "$out/niri-sidebar"
        cp ${niri-sidebar-config} "$out/niri-sidebar/config.toml"
      '';

      niri-sidebar-wrapped = pkgs.symlinkJoin {
        name = "niri-sidebar-wrapped";
        paths = [ niri-sidebar ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/niri-sidebar" \
            --set XDG_CONFIG_HOME "${configDir}"
        '';
      };
    in
    {
      home.packages = [ niri-sidebar-wrapped ];

      wayland.windowManager.niri.settings = {
        binds = {
          "Mod+A" = {
            _props.hotkey-overlay-title = "Toggle Sidebar Floating";
            spawn-sh = "niri-sidebar toggle-window";
          };
          "Mod+Shift+A" = {
            _props.hotkey-overlay-title = "Toggle Sidebar Visibility";
            spawn-sh = "niri-sidebar toggle-visibility";
          };
        };

        _children = lib.mkAfter [
          {
            spawn-at-startup._args = [
              "niri-sidebar"
              "listen"
            ];
          }
        ];
      };
    };
}
