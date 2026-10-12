{
  flake.modules.nixos.snowflake-dracaena =
    { config, ... }:
    {
      services.tailscale = {
        enable = true;
        authKeyFile = config.sops.secrets."tailscale_key".path;
      };
      sops.secrets."tailscale_key" = {
        mode = "0400";
        owner = config.users.users.root.name;
        restartUnits = [ "tailscaled.service" ];
      };
    };
}
