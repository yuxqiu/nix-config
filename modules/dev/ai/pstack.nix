{ inputs, ... }:
{
  flake.modules.homeManager.pstack =
    { pkgs, ... }:
    let
      pstack = pkgs.callPackage (inputs.self + /packages/pstack.nix) { };
      agents = pkgs.runCommand "pstack-claude-agents" { } ''
        mkdir -p "$out/.claude-plugin"
        cp ${pstack.src}/plugins/pstack/.claude-plugin/plugin.json \
          "$out/.claude-plugin/plugin.json"
        cp -r ${pstack.src}/plugins/pstack/agents "$out/agents"
      '';
    in
    {
      home.packages = [ pkgs.bun ];
      programs.claude-code.plugins.pstack = agents;

      programs.agent-skills = {
        sources.pstack = {
          path = pstack;
          subdir = "skills";
          filter.maxDepth = 1;
        };
        skills.enableAll = [ "pstack" ];
        # Home Manager owns the shared Claude skill links and native agent plugin.
        targets.claude = {
          structure = "link";
          dest = ".claude/skills";
        };
      };
    };
}
