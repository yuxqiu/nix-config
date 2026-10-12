{ lib, ... }:
{
  flake.modules.generic.base = {
    options.my.tailnetHosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        my-host = "my-host.tailnet-name.ts.net";
      };
      description = "MagicDNS name of every host, keyed by flake output name, so hosts can address each other.";
    };
  };
}
