{ inputs, ... }:
{
  flake.modules.nixos.fprintd =
    { config, ... }:
    {
      persistence.directories = [
        # fprintd.service's StateDirectoryMode= sets the mode at every start.
        {
          directory = "/var/lib/fprint";
          mode = config.persistence.programSetsMode;
        }
      ];
      imports = [ inputs.fingerprint-lid-guard.nixosModules.default ];

      services.fprintd.enable = true;
    };
}
