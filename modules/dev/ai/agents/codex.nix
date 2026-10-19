{
  flake.modules.homeManager.codex =
    { config, pkgs, ... }:
    {
      home.packages = [ pkgs.bubblewrap ];

      programs = {
        codex = {
          enable = true;
          enableMcpIntegration = true;
          # Codex writes trust_level entries into config.toml when a directory
          # is trusted in the TUI, so keep it writable and merge settings in.
          mutableSettings = true;
          settings = {
            analytics.enabled = false;
            # Updates are managed by Nix.
            check_for_update_on_startup = false;
            web_search = "live";
            tui = {
              keymap.chat.next_permission_mode = "ctrl-tab";
              status_line = [
                "model-with-reasoning"
                "context-used"
                "five-hour-limit"
                "weekly-limit"
                "approval-mode"
              ];
              status_line_use_colors = true;
            };
          };
          # Ingest the shared AGENTS.md content as Codex's global AGENTS.md.
          context = config.my.agents-md.content;
        };

        agent-skills.targets.codex.enable = true;
      };
    };
}
