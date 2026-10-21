{
  flake.modules.nixos.dracaena =
    { config, inputs, ... }:
    let
      local = import "${inputs.nix-secrets}/dracaena.nix";
    in
    {
      sops.secrets."xray.json".restartUnits = [ "xray.service" ];
      services.xray = {
        enable = true;
        settingsFile = config.sops.secrets."xray.json".path;
      };

      security.acme = {
        acceptTerms = true;
        defaults.email = local.acmeEmail;
        certs.${local.domain} = {
          listenHTTP = ":80";
        };
      };

      systemd.services.xray = {
        after = [
          "acme-${local.domain}.service"
          "warp-setup.service"
        ];
        requires = [ "acme-${local.domain}.service" ];
        wants = [ "warp-setup.service" ];
        serviceConfig.SupplementaryGroups = [ "acme" ];
      };
    };
}
