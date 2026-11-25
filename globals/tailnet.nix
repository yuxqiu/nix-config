{ lib, ... }:
{
  # Tailscale MagicDNS name of each host, keyed by its flake output name
  # (`tailnet.cedrus`), available in every NixOS and Home Manager config
  # through `generic.base`.
  flake.modules.generic.base = {
    options.tailnet = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        my-host = "my-host.tailnet-name.ts.net";
      };
      description = "MagicDNS name of every host, keyed by flake output name, so hosts can address each other.";
    };

    config.tailnet = {
      cedrus = "cedrus.taile30f2a.ts.net";
      dracaena = "snowflake.taile30f2a.ts.net";
    };
  };
}
