{
  flake.modules.nixos.usbguard =
    { mv, ... }:
    {
      services.usbguard = {
        # TEMP: nixpkgs usbguard fails to build upstream; use the cached 1.1.4
        # from nixpkgs-multiverse. Drop this line once it builds again.
        package = mv.versions.usbguard."1.1.4";
        implicitPolicyTarget = "block";
        IPCAllowedGroups = [ "usbguard" ];
        dbus.enable = true;
      };

      users.groups.usbguard = { };
    };

  flake.modules.homeManager.usbguard =
    { mv, ... }:
    let
      # TEMP: nixpkgs usbguard-notifier fails to build upstream; use the cached
      # 0.1.1 from nixpkgs-multiverse. Switch back to pkgs once it builds again.
      usbguard-notifier = mv.versions.usbguard-notifier."0.1.1";
    in
    {
      home.packages = [ usbguard-notifier ];

      systemd.user.services.usbguard-notifier = {
        Unit = {
          Description = "USBGuard notification daemon";
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${usbguard-notifier}/bin/usbguard-notifier -w";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
}
