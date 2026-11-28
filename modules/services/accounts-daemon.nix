{
  flake.modules.nixos.accounts-daemon =
    { config, ... }:
    {
      persistence.directories = [
        # accounts-daemon.service's StateDirectoryMode= sets the mode at every start.
        {
          directory = "/var/lib/AccountsService";
          mode = config.persistence.programSetsMode;
        }
      ];
      services.accounts-daemon.enable = true;
    };
}
