{
  # The certificate for the proxy's domain (xray.nix uses it).
  flake.modules.nixos.dracaena =
    { inputs, ... }:
    let
      local = import "${inputs.nix-secrets}/dracaena.nix";
    in
    {
      # The account and certificates, so a reboot does not request new ones.
      persistence.directories = [
        {
          directory = "/var/lib/acme";
          user = "acme";
          group = "acme";
        }
      ];
      security.acme = {
        acceptTerms = true;
        defaults.email = local.acmeEmail;
        certs.${local.domain} = {
          listenHTTP = ":80";
        };
      };
    };
}
