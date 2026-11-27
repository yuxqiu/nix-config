{
  # The certificate for the proxy's domain (xray.nix uses it).
  flake.modules.nixos.dracaena =
    { config, inputs, ... }:
    let
      local = import "${inputs.nix-secrets}/dracaena.nix";
      # The unit that makes /var/lib/acme (its StateDirectory=) and sets its
      # mode at every start.
      setup = config.systemd.services.acme-setup.serviceConfig;
    in
    {
      # The account and certificates, so a reboot does not request new ones.
      persistence.directories = [
        {
          directory = "/var/lib/acme";
          user = setup.User;
          group = setup.Group;
          mode = config.persistence.programSetsMode;
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
