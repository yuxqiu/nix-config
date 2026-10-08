{
  flake.modules.homeManager.dms = {
    programs.dank-material-shell.plugins.niriWindows = {
      enable = true;
      settings = {
        # Show open windows in regular launcher searches, no `!` prefix needed.
        # `!!` still filters to windows on the current workspace.
        noTrigger = true;
        # Pre-seeded so the plugin doesn't try to write it to the read-only settings file.
        trigger = "!";
      };
    };
  };
}
