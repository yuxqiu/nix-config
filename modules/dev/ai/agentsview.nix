{ inputs, ... }:
{
  flake.modules.homeManager.agentsview =
    { pkgs, ... }:
    let
      # https://github.com/kenn-io/agentsview#privacy: disable PostHog telemetry
      wrappedAgentsview = pkgs.symlinkJoin {
        name = "agentsview";
        paths = [ inputs.llm-agents-nix.packages.${pkgs.stdenv.system}.agentsview ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/agentsview \
            --set AGENTSVIEW_TELEMETRY_ENABLED 0
        '';
      };
    in
    {
      home.packages = [ wrappedAgentsview ];
    };
}
