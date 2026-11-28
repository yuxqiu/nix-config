{ inputs, ... }:
{
  flake.modules.homeManager.niri =
    { pkgs, lib, ... }:
    let
      niri-float-sticky = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.niri-float-sticky;
      exe = lib.getExe niri-float-sticky;
    in
    {
      wayland.windowManager.niri.settings = {
        binds."Mod+S" = {
          _props.hotkey-overlay-title = "Toggle Floating Window Sticky";
          spawn = [
            exe
            "-ipc"
            "toggle_sticky"
          ];
        };

        # Opt-in per window: auto-stick would also drag niri-sidebar's
        # floating windows across workspaces.
        _children = lib.mkAfter [
          {
            spawn-at-startup._args = [
              exe
              "-disable-auto-stick"
            ];
          }
        ];
      };
    };
}
