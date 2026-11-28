{
  # The kernel pipes core dumps to systemd-coredump (core_pattern from
  # systemd's sysctl.d/50-coredump.conf); these settings make it discard them.
  flake.modules.nixos.coredump = {
    systemd.coredump.settings.Coredump = {
      Storage = "none";
      ProcessSizeMax = 0;
    };
  };
}
