{
  flake.modules.nixos.cedrus = {
    # usbguard-notifier (a user service) needs IPC access to show device
    # events, and its Allow/Reject buttons need to change device policy; the
    # daemon only talks to IPCAllowedUsers/IPCAllowedGroups. The group has
    # full IPC access, so a process running as this user can also allow a
    # blocked device. Accepted: that only matters together with a malicious
    # device physically plugged in.
    users.users.yuxqiu.extraGroups = [ "usbguard" ];

    # USB devices allowed on this host. Run `lsusb` to find device IDs.
    services.usbguard.rules = ''
      allow with-interface equals { 09:00:00 }
      allow id 27c6:659a    # Goodix fingerprint sensor
      allow id 04f2:b875    # Chicony integrated camera
    '';
  };
}
