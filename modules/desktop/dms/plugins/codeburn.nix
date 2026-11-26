{
  inputs,
  ...
}:
{
  flake.modules.homeManager.dms =
    { pkgs, ... }:
    let
      codeburn = pkgs.callPackage (inputs.self + /packages/codeburn.nix) { };
    in
    {
      # codeburn's parsed-session cache. Rebuilding it takes longer than the
      # plugin's 15 s CLI timeout (measured 17 s and 2.6 GB with ~330
      # sessions), so without it every refresh after a boot is killed before
      # the cache is written and starts over. Kept as a directory: entries are
      # written to temp files and renamed into place.
      persistence.directories = [ ".cache/codeburn" ];
      programs.dank-material-shell.plugins.codeburn = {
        enable = true;
        # Point the provider script at the store path directly so it doesn't
        # depend on the DMS systemd service inheriting the HM profile PATH.
        settings = {
          cliPath = "${codeburn}/bin/codeburn";
          compactMode = true;
          # Seconds between refreshes; each runs the CLI once per bar. 300 is
          # the plugin's maximum (CodeBurnWidget.qml clamps to 5..300).
          refreshInterval = 300;
        };
      };

      home.packages = [
        codeburn
        pkgs.jq
      ];
    };
}
