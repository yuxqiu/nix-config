{ inputs, ... }:
{
  flake.modules.homeManager.terminal-browser =
    { pkgs, ... }:
    let
      terminal-browser = inputs.llm-agents-nix.packages.${pkgs.stdenv.system}.terminal-browser;
    in
    {
      home.packages = [ terminal-browser ];
    };
}
