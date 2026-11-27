{ inputs, ... }:
{
  flake.modules.nixos.dracaena =
    { lib, ... }:
    let
      # disko formats a partition through its /dev/disk/by-partlabel link
      # right after `udevadm settle`, which only checks that udevd's queue is
      # empty, not that it has received every event the kernel sent. Creating
      # the second partition re-reads the table; udev removes and re-adds the
      # first one's link, so in the kexec installer mkfs found it missing
      # ("unable to open /dev/disk/by-partlabel/disk-main-ESP",
      # nix-community/disko#739). Wait for that exact link instead: disko sets
      # $device before running this hook. 120 s is disko's own settle timeout.
      waitForPartition = ''udevadm wait --timeout=120 "$device"'';
    in
    {
      imports = [ inputs.disko.nixosModules.disko ];

      warnings = lib.optional (lib.hasInfix "udevadm wait" (builtins.readFile "${inputs.disko}/lib/types/gpt.nix")) "disko.nix: disko now waits for partition links itself (udevadm wait in lib/types/gpt.nix); remove waitForPartition, its preCreateHook uses, and this warning.";

      disko.devices = {
        disk.main = {
          device = "/dev/sda";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  # Only root reads the boot loader's random seed.
                  mountOptions = [ "umask=0077" ];
                  preCreateHook = waitForPartition;
                };
              };
              # The store and the kept state as separate subvolumes, so neither
              # mount depends on the other at shutdown.
              root = {
                size = "100%";
                content = {
                  type = "btrfs";
                  preCreateHook = waitForPartition;
                  subvolumes = {
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@persist" = {
                      mountpoint = "/persist";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                  };
                };
              };
            };
          };
        };
        # Root on tmpfs is set by nixos.ephemeral-root.
      };
      fileSystems."/persist".neededForBoot = true;
    };
}
