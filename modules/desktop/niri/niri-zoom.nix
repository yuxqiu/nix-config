{ inputs, ... }:
{
  flake.modules.homeManager.niri =
    { pkgs, lib, ... }:
    let
      niri-zoom = pkgs.callPackage (inputs.self + /packages/niri-zoom.nix) { };
      ctl = "${niri-zoom}/bin/niri-zoomctl";
      daemon = "${niri-zoom}/bin/niri-zoomd";
    in
    {
      wayland.windowManager.niri.settings = {
        binds = {
          "Mod+Shift+WheelScrollUp" = {
            _props.cooldown-ms = 0;
            spawn = [
              ctl
              "in"
            ];
          };
          "Mod+Shift+WheelScrollDown" = {
            _props.cooldown-ms = 0;
            spawn = [
              ctl
              "out"
            ];
          };
          # Natural-scroll inverts the physical gesture on touchpads, so
          # swap up/down to keep "swipe up = zoom in" feeling intuitive.
          "Mod+Shift+TouchpadScrollUp" = {
            _props.cooldown-ms = 0;
            spawn = [
              ctl
              "out"
            ];
          };
          "Mod+Shift+TouchpadScrollDown" = {
            _props.cooldown-ms = 0;
            spawn = [
              ctl
              "in"
            ];
          };
          "Mod+Shift+Z".spawn = [
            ctl
            "reset"
          ];
        };

        _children = lib.mkAfter [
          { spawn-at-startup._args = [ daemon ]; }
        ];
      };
    };
}
