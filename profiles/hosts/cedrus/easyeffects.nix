{ inputs, ... }:
{
  flake.modules.homeManager.cedrus =
    { pkgs, ... }:
    let
      presets = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.easyeffects-dolby;
      speakerSink = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink";
    in
    {
      # Dolby on the internal speaker; every other output falls back to Nothing.
      xdg.dataFile = {
        "easyeffects/output" = {
          source = "${presets}/output";
          recursive = true;
        };
        "easyeffects/irs" = {
          source = "${presets}/irs";
          recursive = true;
        };
        "easyeffects/autoload/output/${speakerSink}:Speaker.json".text = builtins.toJSON {
          device = speakerSink;
          device-description = "Core Ultra Processors (Series 3) HD Audio Speaker";
          device-profile = "Speaker";
          preset-name = "Dolby-Balanced";
        };
      };

      services.easyeffects = {
        extraPresets.Nothing.output = {
          blocklist = [ ];
          plugins_order = [ ];
        };
        settings.Window = {
          outputAutoloadingFallbackPreset = "Nothing";
          outputAutoloadingUsesFallback = true;
        };
      };
    };
}
