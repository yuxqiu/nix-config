{ ... }:
{
  flake.modules.homeManager.orchestrator = {
    programs.agent-skills = {
      # Operating loop adapted from the "Chief of Staff" pattern:
      # https://asyncdot.com/blog/chief-of-staff-pattern-orchestrating-claude-code-sessions/
      sources.orchestrator = {
        path = ./skills;
        subdir = ".";
      };

      skills.enableAll = [ "orchestrator" ];
    };
  };
}
