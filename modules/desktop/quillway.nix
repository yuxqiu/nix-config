{ inputs, ... }:
{
  flake.modules.homeManager.quillway =
    { config, ... }:
    {
      imports = [ inputs.quillway.homeManagerModules.default ];

      services.quillway = {
        enable = true;
        settings.ui.opacity = config.stylix.opacity.popups;
        # Unload the model after 5 min idle to free VRAM/RAM.
        settings.model.extra_args = [
          "--sleep-idle-seconds"
          "300"
        ];
      };

      # Mod+Space is taken by the DMS launcher.
      wayland.windowManager.niri.settings.binds."Mod+Shift+Space" = {
        _props.hotkey-overlay-title = "Quillway Rewrite";
        spawn = [
          "quillway"
          "toggle"
        ];
      };
    };
}
