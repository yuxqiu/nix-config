{
  flake.modules.nixos.dracaena = {
    networking.hostName = "snowflake";
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
