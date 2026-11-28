{
  flake.modules.homeManager.lowfi =
    { pkgs, ... }:
    let
      lowfi = pkgs.lowfi.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
        postFixup = (old.postFixup or "") + ''
          wrapProgram $out/bin/lowfi \
            --set ALSA_PLUGIN_DIR "${pkgs.alsa-plugins}/lib/alsa-lib"
        '';
      });
    in
    {
      home.packages = [
        lowfi
      ];
    };
}
