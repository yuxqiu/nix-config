{
  inputs,
  ...
}:
{
  flake.modules.homeManager.flatpak =
    { pkgs, ... }:
    {
      imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

      home.packages = [ pkgs.flatpak ];

      services.flatpak = {
        enable = true;
        update = {
          onActivation = false;
          auto.enable = true;
        };
        uninstallUnused = true; # delete stale/unused packages

        packages = [
          "com.github.johnfactotum.Foliate"
          "com.github.tchx84.Flatseal"
          "io.mpv.Mpv"
          "org.gnome.Calculator"
          "org.gnome.FileRoller"
          "org.libreoffice.LibreOffice"
          "org.inkscape.Inkscape"
          "net.sapples.LiveCaptions"
          "io.frama.tractor.carburetor"
          "org.gnome.gitlab.YaLTeR.VideoTrimmer"
          "org.gnome.Snapshot"
          "com.github.PintaProject.Pinta"
          "com.github.flxzt.rnote"
        ];

        overrides = {
          global = {
            # Force
            # - Wayland by default
            # - No smart cards (pcsc: YubiKey), printer, gpg and ssh
            Context.sockets = [
              "wayland"
              "!x11"
              "!fallback-x11"
              "!pcsc"
              "!cups"
              "!ssh-auth"
              "!gpg-agent"
            ];
            # Deny network access by default
            Context.shared = [
              "!network"
              "!ipc"
            ];

            Context.filesystems = [
              # Read-only access to nix store, which stores resources like cursors
              # https://wiki.nixos.org/wiki/Cursor_Themes
              "/nix/store:ro"
            ];

            # From
            # - https://github.com/gentmantan/dotfiles/blob/b693ee1893c619f53cfecd7bc154db914262c0b1/modules/nix-flatpak.nix
            "System Bus Policy" = {
              "org.freedesktop.UPower" = "none";
              "org.freedesktop.UDisks2" = "none";
            };
            "Session Bus Policy" = {
              # Deny some known sandbox escape permissions
              "org.freedesktop.Flatpak" = "none";
              "org.freedesktop.impl.portal.PermissionStore" = "none";
              "org.freedesktop.secrets" = "none";
            };
          };

          "io.frama.tractor.carburetor" = {
            Context.shared = [
              "network"
              "ipc"
            ];
          };
        };
      };
    };

  flake.modules.nixos.flatpak = {
    services.flatpak.enable = true;
  };
}
