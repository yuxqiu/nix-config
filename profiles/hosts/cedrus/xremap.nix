{
  flake.modules.nixos.cedrus =
    let
      capsEscComposeRemap = {
        "KEY_CAPSLOCK" = "KEY_ESC";
        "KEY_ESC" = {
          alone = "KEY_CAPSLOCK";
          held = "KEY_COMPOSE";
          hold_threshold_millis = 150;
        };
      };
    in
    {
      services.xremap = {
        userName = "yuxqiu";
        config.modmap = [
          {
            name = "internal-keyboard-remaps";
            device.only = [ "AT Translated Set 2 keyboard" ];
            remap = capsEscComposeRemap // {
              "KEY_LEFTMETA" = "KEY_LEFTALT";
              "KEY_LEFTALT" = "KEY_LEFTCTRL";
            };
          }
          {
            name = "external-keyboard-remaps";
            device.only = [ "Eyelash Sofle Keyboard" ];
            remap = capsEscComposeRemap;
          }
        ];
      };
    };
}
