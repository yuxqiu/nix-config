{ inputs, ... }:
{
  flake.modules.homeManager.mdbrowse =
    { config, pkgs, ... }:
    let
      mdbrowseUnwrapped = inputs.mdbrowse.packages.${pkgs.stdenv.system}.default;
      mdbrowse = pkgs.writeShellApplication {
        name = "mdbrowse";
        runtimeInputs = [
          mdbrowseUnwrapped
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
