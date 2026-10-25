{ inputs, ... }:
{
  flake.modules.homeManager.opencode =
    { pkgs, ... }:
    let
      opencodeQueue = pkgs.callPackage (inputs.self + /packages/opencode-queue.nix) { };
      goalPlugin = pkgs.callPackage (inputs.self + /packages/opencode-goal.nix) { };
    in
    {
      # Other Interesting Plugins
      # - opencode-background-agents (seems a bit overkill)
      # - open-ralph-wiggum
      # - opencode-dynamic-context-pruning (useful with token-based plan)
      programs.opencode = {
        enable = true;
        enableMcpIntegration = true;
        package = pkgs.opencode;
        mutableSettings = true;
        settings = {
          autoupdate = false;
          plugins = [
            "file://${goalPlugin}/lib/opencode-goal-plugin"
          ];
        };
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

      my.agents-md.destinations.opencode = ".config/opencode/AGENTS.md";
    };
}
