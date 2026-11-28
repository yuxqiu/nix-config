{ config, ... }:
{
  # What a coding agent session needs, as one module: hosts include it, and
  # so does vm-run's agent VM. The boundary: the agent CLIs, what they load
  # (instructions, skills, MCP servers), and the tools they run themselves,
  # all usable headless in a terminal. Not here: tools for the person to
  # watch, review or drive agents (agentsview, herdr, hunk, paseo), and AI
  # helpers the person runs (geminicommit, opencodecommit).
  flake.modules.homeManager.agents.imports = with config.flake.modules.homeManager; [
    agents-md
    skills
    mcp
    pstack
    harness
    agent-browser
    antigravity
    claude
    codex
    devin
    opencode
  ];
}
