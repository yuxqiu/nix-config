{
  flake.modules.nixos.bolt = {
    persistence.directories = [ "/var/lib/boltd" ];
    services.hardware.bolt.enable = true;
  };
}
