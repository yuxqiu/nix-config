{
  flake.modules.nixos.cedrus = {
    services.fprintd.lid-guard = {
      enable = true;
      lidPath = "LID0";
    };
  };
}
