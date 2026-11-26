{
  flake.modules.homeManager.sioyek =
    { pkgs, lib, ... }:
    {
      persistence.directories = [ ".local/share/sioyek" ];
      programs.sioyek = {
        enable = true;
        bindings = {
          goto_tab = "gt";
          add_bookmark = "bb";
          add_freetext_bookmark = "bf";
          add_marked_bookmark = "bm";
          _print = "<C-p>";
        };
        config = {
          check_for_updates_on_startup = "0";
          super_fast_search = "1";
          show_document_name_in_statusbar = "1";
          show_closest_bookmark_in_statusbar = "1";
          status_bar_font_size = "15";
          font_size = "15";
          # Pop up yad's native GTK print dialog for the current PDF.
          # --type=RAW prevents yad from trying to render the PDF as text;
          # --add-preview is incompatible with --type=RAW so it's omitted.
          "new_command _print" = "${lib.getExe pkgs.yad} --print --filename=%1 --type=RAW";
        };
      };

      xdg.mimeApps = {
        associations.added = {
          "application/pdf" = [ "sioyek.desktop" ];
        };

        defaultApplications = {
          "application/pdf" = [ "sioyek.desktop" ];
        };
      };
    };
}
