{
  flake.modules.nixos.dracaena =
    { lib, ... }:
    {
      services.tailscale = {
        # OpenSSH (key-only) already serves this host. Tailscale SSH's browser
        # check would hang non-interactive ssh (pair-remote, git fetch, deploys).
        # `up` flags only apply on first join; `set` turns it off on a live node.
        extraUpFlags = lib.mkForce [ ];
        extraSetFlags = [ "--ssh=false" ];
      };
    };
}
