{ inputs, ... }:
{
  flake.modules.homeManager.pstack =
    { pkgs, ... }:
    let
      pstack = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.pstack;
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

      skills.sources.pstack = "${pstack}/skills";
    };
}
