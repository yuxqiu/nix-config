{
  flake.modules.homeManager.xdg = {
    xdg.enable = true;
    xdg.userDirs.enable = true;
    xdg.autostart.enable = true;
    xdg.mime.enable = true;
    xdg.mimeApps.enable = true;
    xdg.portal.enable = true;
    xdg.terminal-exec.enable = true;
  };

  flake.modules.nixos.xdg = {
    xdg.portal.enable = true;
  };
}
