# VM test: disko formats partitions only after udev has created their
# /dev/disk/by-partlabel links. Each filesystem's preCreateHook runs
# `udevadm wait "$device"` (as in profiles/hosts/dracaena/disko.nix), which
# returns once the link exists and udevd has initialized it. The test lays out
# an empty disk like dracaena's (ESP plus btrfs with @nix and @persist) and
# checks that the waits ran on the label paths, mkfs succeeded, and both are
# mounted by label.
{
  pkgs,
  disko,
}:
let
  waitForPartition = ''udevadm wait --timeout=120 "$device" && echo "waited for $device" >&2'';
  scripts =
    (pkgs.nixos {
      imports = [ disko ];
      disko.devices.disk.main = {
        device = "/dev/vdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "128M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                preCreateHook = waitForPartition;
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                preCreateHook = waitForPartition;
                subvolumes = {
                  "@nix".mountpoint = "/nix";
                  "@persist".mountpoint = "/persist";
                };
              };
            };
          };
        };
      };
      boot.loader.grub.enable = false;
      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
      };
      system.stateVersion = "26.11";
    }).config.system.build;
in
pkgs.testers.runNixOSTest {
  name = "disko-wait";
  globalTimeout = 300;

  nodes.machine = {
    virtualisation.emptyDiskImages = [ 1024 ];
    environment.systemPackages = [ pkgs.btrfs-progs ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("each partition is formatted after its label link exists"):
        out = machine.succeed("${scripts.formatScript} 2>&1")
        assert "waited for /dev/disk/by-partlabel/disk-main-ESP" in out, out
        assert "waited for /dev/disk/by-partlabel/disk-main-root" in out, out
        machine.succeed("blkid -o value -s TYPE /dev/disk/by-partlabel/disk-main-ESP | grep -x vfat")
        machine.succeed("blkid -o value -s TYPE /dev/disk/by-partlabel/disk-main-root | grep -x btrfs")

    with subtest("the layout mounts by label"):
        machine.succeed("${scripts.mountScript}")
        machine.succeed("findmnt -n -o FSTYPE /mnt/boot | grep -x vfat")
        machine.succeed("findmnt -n -o FSTYPE,FSROOT /mnt/nix | grep -x 'btrfs /@nix'")
        machine.succeed("findmnt -n -o FSTYPE,FSROOT /mnt/persist | grep -x 'btrfs /@persist'")
  '';
}
