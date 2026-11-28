{ inputs, ... }:
{
  flake.modules.nixos.fprintd =
    { config, ... }:
    {
      imports = [ inputs.fingerprint-lid-guard.nixosModules.default ];

      persistence.directories = [
        # fprintd.service's StateDirectoryMode= sets the mode at every start.
        {
          directory = "/var/lib/fprint";
          mode = config.persistence.programSetsMode;
        }
      ];

      services.fprintd.enable = true;
    };
}
