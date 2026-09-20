{ inputs, ... }:
{
  flake.modules.homeManager.mdbrowse =
    { config, pkgs, ... }:
    let
      terminal-browser = inputs.llm-agents-nix.packages.${pkgs.stdenv.system}.terminal-browser;
      mdbrowseUnwrapped = inputs.mdbrowse.packages.${pkgs.stdenv.system}.default;
      mdbrowse = pkgs.writeShellApplication {
        name = "mdbrowse";
        runtimeInputs = [
          mdbrowseUnwrapped
          terminal-browser
        ];
        text = ''
          exec mdbrowse \
            --zoom 1.2 \
            --bg '${config.lib.stylix.colors.withHashtag.base00}' \
            "$@"
        '';
      };
    in
    {
      home.packages = [ mdbrowse ];
    };
}
