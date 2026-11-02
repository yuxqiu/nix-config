{
  flake.modules.homeManager.wayscriber =
    { lib, pkgs, ... }:
    let
      # Read nixpkgs' package source (not its output) to avoid IFD.
      packageFile = lib.head (lib.splitString ":" pkgs.wayscriber.meta.position);
    in
    {
      home.packages = with pkgs; [ wayscriber ];

      warnings = lib.optional (lib.hasInfix ".desktop" (builtins.readFile packageFile)) ''
        wayscriber.nix: nixpkgs' wayscriber (${packageFile}) now mentions a .desktop file.
        If it installs upstream's packaging/wayscriber.desktop, remove the custom
        xdg.desktopEntries.wayscriber and this warning.
      '';

      # Pinned nixpkgs installs only bin/; upstream ships packaging/wayscriber.desktop.
      xdg.desktopEntries.wayscriber = {
        name = "Wayscriber";
        comment = "Live overlay for drawing, annotating, and screenshots (Wayland whiteboard)";
        genericName = "Drawing Overlay";
        exec = "wayscriber --active";
        icon = "accessories-drawing";
        terminal = false;
        type = "Application";
        categories = [
          "Graphics"
          "Utility"
          "2DGraphics"
        ];
        startupNotify = false;
        settings = {
          Keywords = "drawing;whiteboard;annotate;screenshot;wayland;overlay";
        };
      };
    };
}
