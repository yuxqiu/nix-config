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

    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
