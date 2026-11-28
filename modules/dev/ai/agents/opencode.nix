{ inputs, ... }:
{
  flake.modules.homeManager.opencode =
    {
      config,
      pkgs,
      ...
    }:
    let
      opencodeQueue = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode-queue;
    in
    {
      persistence.directories = [
        ".local/share/opencode"
        {
          directory = ".local/share/opencode-goal-plugin";
          mode = "0700";
        }
        ".local/share/btw-opencode"
        {
          directory = ".opencode-goal-plugin";
          mode = "0700";
        }
      ];
      # Other Interesting Plugins
      # - opencode-background-agents (seems a bit overkill)
      # - open-ralph-wiggum
      # - opencode-dynamic-context-pruning (useful with token-based plan)
      programs.opencode = {
        enable = true;
        enableMcpIntegration = true;
        mutableSettings = true;
        settings.autoupdate = false;
        context = config.agents-md.content;
        cli = {
          attention = {
            notifications = true;
            sound = false;
          };
        };
      };

      # opencode-queue plugin - queue input until session is idle
      # https://github.com/mirsella/opencode-queue
      home.file.".config/opencode/plugins/opencode-queue.js".source =
        "${opencodeQueue}/lib/opencode-queue/index.js";

      programs.agent-skills.targets.opencode.enable = true;
    };
}
