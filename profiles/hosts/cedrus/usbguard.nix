{
  flake.modules.nixos.cedrus = {
    # Host-specific USB device whitelist
    # Blocks all USB devices by default; only listed devices are allowed.
    # Run `lsusb` to find device IDs, then add them here.
    users.users.yuxqiu.extraGroups = [ "usbguard" ];
    services.usbguard = {
      enable = true;
      rules = ''
        allow with-interface equals { 09:00:00 }
        allow id 27c6:659a    # Goodix fingerprint sensor
        allow id 04f2:b875    # Chicony integrated camera
      '';
    };
  };
}
