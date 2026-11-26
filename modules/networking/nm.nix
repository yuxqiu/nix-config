{
  flake.modules.homeManager.nm = { pkgs, ... }: {
    home.packages = with pkgs; [ networkmanagerapplet ];

    # networkmanagerapplet ships an XDG autostart entry that launches nm-applet
    # on every session. Mask it with a Hidden=true override so it doesn't
    # autostart; the binary is still available to run manually.
    xdg.configFile."autostart/nm-applet.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=NetworkManager Applet
      Exec=nm-applet
      Hidden=true
    '';
  };

  flake.modules.nixos.nm = {
    persistence.directories = [
      {
        directory = "/etc/NetworkManager/system-connections";
        mode = "0700";
      }
    ];
    networking.networkmanager = {
      enable = true;
      wifi.macAddress = "random";
      ethernet.macAddress = "random";

      settings = {
        connectivity.enabled = false;

        "device-mac-randomization"."wifi.scan-rand-mac-address" = true;
      };

      connectionConfig = {
        "ipv4.dhcp-send-hostname" = false;
        "ipv6.dhcp-send-hostname" = false;
      };
    };

    # Profiles are kept across reboots in system-connections, both system-wide
    # ones and ones restricted to a user (connection.permissions), and a
    # profile can carry DNS, a VPN or a proxy. NetworkManager's polkit defaults
    # let the active session create and edit its own profiles without a
    # password (settings.modify.own = yes), so require admin authentication
    # for that too, as for system-wide ones. Connecting to saved profiles
    # (network-control) stays password-free.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.NetworkManager.settings.modify.own") {
          return polkit.Result.AUTH_ADMIN_KEEP;
        }
      });
    '';
  };
}
