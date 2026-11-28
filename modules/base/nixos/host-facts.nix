{
  # What os-install and os-bootstrap need to know about a host, in one value
  # they read with a single `nix eval --json`.
  flake.modules.nixos.base =
    { config, lib, ... }:
    let
      # The root is wiped at boot (modules/base/ephemeral-root.nix), which
      # declares persistence.storage and persistence.keptPaths.
      ephemeralRoot = config.preservation.enable or false;
      inherit (config.persistence) storage;
      storageFileSystem = config.fileSystems.${storage} or null;
    in
    {
      options.hostFacts = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        description = "Facts about the host read by os-install and os-bootstrap.";
        default = {
          # Where the running host reads its age key. With an ephemeral root
          # its directory is kept: the file itself is at the same path under
          # `storage.mountPoint`.
          inherit (config.sops.age) keyFile;
          # The persistent filesystem of a host with an ephemeral root, null
          # otherwise. `fileSystem` is null when the config mounts nothing at
          # `mountPoint`.
          storage =
            if ephemeralRoot then
              {
                mountPoint = storage;
                fileSystem =
                  if storageFileSystem == null then
                    null
                  else
                    {
                      inherit (storageFileSystem) device options;
                    };
              }
            else
              null;
          # Every path copied by os-install --keep-state.
          keptPaths = if ephemeralRoot then config.persistence.keptPaths else [ ];
          # Secrets installed before users are created (password hashes); a
          # user whose secret is missing from the secrets file gets no
          # password.
          secretsNeededForUsers = lib.attrNames (
            lib.filterAttrs (_: s: s.neededForUsers) config.sops.secrets
          );
        };
      };
    };
}
