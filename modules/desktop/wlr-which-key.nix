_: {
  flake.modules.homeManager.wlr-which-key = {
    programs.wlr-which-key.enable = true;

    wayland.windowManager.niri.settings.binds."Mod+M" = {
      spawn-sh = "wlr-which-key pointer";
    };
  };
}
