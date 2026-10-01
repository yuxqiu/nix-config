{
  flake.modules.nixos.usbguard =
    { mv, ... }:
    {
      services.usbguard = {
        # TEMP: nixpkgs usbguard fails to build upstream; use the cached 1.1.4
        # pinned to nixpkgs 7a0f122f5090 via multiverse. Drop this line once it builds again.
        package = (mv.at "7a0f122f5090").usbguard;
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
      # 0.1.1 pinned to nixpkgs 7a0f122f5090 via multiverse. Switch back to pkgs once it builds again.
      usbguard-notifier = (mv.at "7a0f122f5090").usbguard-notifier;
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
