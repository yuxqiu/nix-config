{ ... }:
{
  flake.modules.homeManager.agent-browser =
    { pkgs, ... }:
    let
      agentBrowser = pkgs.symlinkJoin {
        name = "agent-browser";
        paths = [ pkgs.agent-browser ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/agent-browser \
            --set AGENT_BROWSER_EXECUTABLE_PATH ${pkgs.chromium}/bin/chromium
        '';
      };
    in
    {
      home.packages = [
        agentBrowser
        pkgs.chromium
      ];

      programs.agent-skills = {
        sources.agent-browser = {
          path = pkgs.agent-browser;
          subdir = "skills";
        };

        skills.enableAll = [
          "agent-browser"
        ];
      };
    };
}
