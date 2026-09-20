{
  flake.modules.homeManager.claude =
    { config, pkgs, ... }:
    let
      # Renders: "Usage: 34% (resets in 2h 47m)  Context: 56%  [Opus 4.6]"
      # Usage/reset come from rate_limits.five_hour (Pro/Max subscribers only;
      # segment is omitted when absent, e.g. on non-subscriber plans).
      statusline = pkgs.writeShellApplication {
        name = "claude-statusline";
        runtimeInputs = [ pkgs.jq ];
        text = ''
          input=$(cat)

          model=$(echo "$input" | jq -r '.model.display_name')
          context_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
          usage_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
          resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

          segments=()

          if [ -n "$usage_pct" ]; then
            reset_str=""
            if [ -n "$resets_at" ]; then
              diff=$(( resets_at - $(date +%s) ))
              if [ "$diff" -gt 0 ]; then
                reset_str=" (resets in $(( diff / 3600 ))h $(( (diff % 3600) / 60 ))m)"
              fi
            fi
            segments+=("Usage: $(printf '%.0f' "$usage_pct")%''${reset_str}")
          fi

          if [ -n "$context_pct" ]; then
            segments+=("Context: $(printf '%.0f' "$context_pct")%")
          fi

          segments+=("[$model]")

          IFS=' '
          echo "''${segments[*]}"
        '';
      };
    in
    {
      programs = {
        claude-code = {
          enable = true;
          enableMcpIntegration = true;
          settings = {
            includeCoAuthoredBy = false;
            permissions.defaultMode = "acceptEdits";
            # https://code.claude.com/docs/en/data-usage
            env = {
              DISABLE_TELEMETRY = "1";
              DISABLE_ERROR_REPORTING = "1";
            };
            statusLine = {
              type = "command";
              command = "${statusline}/bin/claude-statusline";
              padding = 0;
            };
          };
          # Ingest the shared AGENTS.md content as Claude Code's global CLAUDE.md.
          context = config.my.agents-md.content;
        };

        agent-skills.targets.claude.enable = true;
      };
    };
}
