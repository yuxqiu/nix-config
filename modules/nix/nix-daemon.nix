{
  # Part of the base module, so every NixOS host gets the same daemon settings.
  flake.modules.nixos.base =
    { lib, ... }:
    {
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          # A trusted user can set any option for the daemon, which runs as
          # root, so only root is trusted; forced so no module adds a user.
          trusted-users = lib.mkForce [ "root" ];
          auto-optimise-store = true;
          accept-flake-config = true;
          # Parallel downloads; Nix's default is 25.
          http-connections = 50;
          # Keep build inputs of live outputs, so garbage collection does not
          # throw away what a rebuild of a kept system or dev shell needs.
          keep-derivations = true;
          keep-outputs = true;
          # When free space drops below min-free during a build, collect garbage
          # until max-free is free (1 GiB and 5 GiB, in bytes).
          min-free = 1024 * 1024 * 1024;
          max-free = 5 * 1024 * 1024 * 1024;
        };

        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };
      };
    };
}
