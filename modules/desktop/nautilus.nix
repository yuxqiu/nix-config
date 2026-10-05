{
  flake.modules.homeManager.nautilus =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.lib.stylix) colors;
      inherit (config.stylix) opacity;

      # Adapted from https://github.com/Lyndeno/nix-config/pull/476 (MIT).
      # Nautilus paints itself opaque, so clear the toplevel and everything
      # inside the sidebar pane, repaint the pane translucent, and repaint the
      # content pane opaque; niri then blurs what shows through the sidebar.
      window = "window.nautilus-window";
      sidebarPane = ".sidebar-pane";
      # Collapsed, AdwOverlaySplitView swaps the pane classes and the sidebar
      # overlays the content, so there is nothing behind it to blur.
      collapsedSidebarPane = "overlay-split-view > widget.background";
      contentPane = "overlay-split-view > widget:not(.sidebar-pane):not(.background)";
      sidebarChildren = [
        ""
        " headerbar"
        " headerbar > windowhandle > box"
        " searchbar > revealer > box"
        " .toolbar"
        " placessidebar"
        " sidebar"
        " scrolledwindow"
        " listview"
        " list"
        " .navigation-sidebar"
      ];
      selectors = lib.concatMapStringsSep ",\n" (rest: "${window} ${rest}");
    in
    {
      home.packages = [ pkgs.nautilus ];

      xdg.mimeApps = {
        associations.added = {
          "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
        };

        defaultApplications = {
          "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
        };
      };

      stylix.targets.gtk.extraCss = ''
        ${window}.background,
        ${window}.view,
        ${selectors (
          [ "> widget" ]
          ++ map (child: sidebarPane + child) sidebarChildren
          ++ map (child: collapsedSidebarPane + child) sidebarChildren
        )} {
          background-color: transparent;
          background-image: none;
        }

        ${window} ${sidebarPane} {
          background-color: alpha(#${colors.base00}, ${toString opacity.desktop});
        }

        ${window} ${collapsedSidebarPane} {
          background-color: #${colors.base01};
        }

        ${window} ${contentPane} {
          background-color: #${colors.base00};
        }
      '';

      wayland.windowManager.niri.settings._children = lib.mkAfter [
        {
          window-rule = {
            match._props."app-id" = "^org\\.gnome\\.Nautilus$";
            background-effect.blur = true;
          };
        }
      ];
    };

  flake.modules.nixos.nautilus = {
    # Trash, network browsing, and other GIO virtual filesystems
    services.gvfs.enable = true;
  };
}
