{
  flake.modules.nixos.snowflake-dracaena =
    { config, lib, ... }:
    {
      services.tailscale = {
        enable = true;
        authKeyFile = config.sops.secrets."tailscale_key".path;
        # OpenSSH (key-only) already serves this host. Tailscale SSH's browser
        # check would hang non-interactive ssh (pair-remote, git fetch, deploys).
        # `up` flags only apply on first join; `set` turns it off on a live node.
        extraUpFlags = lib.mkForce [ ];
        extraSetFlags = [ "--ssh=false" ];
      };
      sops.secrets."tailscale_key" = {
        mode = "0400";
        owner = config.users.users.root.name;
        restartUnits = [ "tailscaled.service" ];
      };
    };
}
