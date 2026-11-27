# VM test: the local route with an ephemeral root in the README's "Setting up a
# machine" (graphical installer, converted in place). The disk is laid out the way the NixOS
# graphical installer lays out LUKS + btrfs: LUKS2 opened as `luks-<uuid>`,
# `/` on the btrfs top level, subvolumes `home` and `nix`, the ESP at /boot
# with fmask/dmask 0077 (calamares-nixos-extensions config/modules/mount.conf
# and partition.conf). `generic` stands in for the system the installer
# writes. It is converted in place with `nixos-rebuild boot` into `converted`:
# `/` on tmpfs, the btrfs top level (the old root) at /persist, `/nix` still
# its own subvolume. Checks that the converted system boots with existing
# state kept, shuts down without "Failed unmounting", and that the previous
# generation still boots the old root.
{
  pkgs,
  nixosEphemeralRoot,
  nixosBase,
  genericBase,
}:
let
  # Fixed identifiers, so the configs can name the filesystems the way a
  # generated hardware-configuration.nix does.
  espVolumeId = "ABCD1234";
  espUuid = "ABCD-1234";
  luksUuid = "3d8e2b47-91a6-4c0f-8b5e-2f7a6c1d9e30";
  btrfsUuid = "a5c1f0e2-6b7d-4e83-9f24-0c8b3a7d5e61";
  luksName = "luks-${luksUuid}";
  btrfsDevice = "/dev/disk/by-uuid/${btrfsUuid}";
  passphrase = "correct horse battery staple";
  # MiB, for every VM. luksFormat sets the Argon2id memory cost to at most
  # half the formatting machine's RAM, capped at 1 GiB (cryptsetup 2.8.8,
  # lib/utils_pbkdf.c), and unlocking needs that much.
  memoryMiB = 2048;

  # What both systems share from the generated hardware-configuration.nix.
  hardware =
    { modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/testing/test-instrumentation.nix")
        (modulesPath + "/profiles/qemu-guest.nix")
      ];
      boot.initrd.luks.devices.${luksName}.device = "/dev/disk/by-uuid/${luksUuid}";
      fileSystems."/nix" = {
        device = btrfsDevice;
        fsType = "btrfs";
        options = [
          "subvol=nix"
          "compress=zstd"
          "noatime"
        ];
      };
      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/${espUuid}";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };
      boot.loader.systemd-boot.enable = true;
      # The installer VM and the installed VM share no EFI variables, so the
      # installed VM's firmware starts the fallback loader EFI/BOOT/BOOTX64.EFI.
      boot.loader.efi.canTouchEfiVariables = false;
      users.users.alice.isNormalUser = true;
      networking.hostName = "desktop";
      documentation.enable = false;
      system.stateVersion = "26.11";
    };

  converted =
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        hardware
        nixosEphemeralRoot
        # Home Manager, which nixos.ephemeral-root configures.
        nixosBase
        genericBase
        {
          # The old root, with the `home` and `nix` subvolumes inside it.
          fileSystems."/persist" = {
            device = btrfsDevice;
            fsType = "btrfs";
            options = [
              "subvol=/"
              "compress=zstd"
              "noatime"
            ];
            neededForBoot = true;
          };
          persistence.storage = "/persist";
          # Declares Home Manager's `persistence` options.
          home-manager.sharedModules = [ genericBase ];
          # A desktop reads this from sops (`neededForUsers`). The test writes
          # it from the generic system, at the top level that becomes /persist.
          users.users.alice.hashedPasswordFile = "/persist/alice.hash";
          home-manager.users.alice = {
            home.stateVersion = "26.11";
            persistence.directories = [ "Documents" ];
          };
        }
      ];
    }).config.system.build.toplevel;

  # Stands in for the system the graphical installer writes. Carries the
  # converted system in its store, where `nixos-rebuild boot` would build it.
  generic =
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        hardware
        {
          fileSystems."/" = {
            device = btrfsDevice;
            fsType = "btrfs";
            options = [
              "compress=zstd"
              "noatime"
            ];
          };
          fileSystems."/home" = {
            device = btrfsDevice;
            fsType = "btrfs";
            options = [
              "subvol=home"
              "compress=zstd"
              "noatime"
            ];
          };
          environment.etc."converted".source = converted;
          environment.systemPackages = [ pkgs.mkpasswd ];
        }
      ];
    }).config.system.build.toplevel;
in
pkgs.testers.runNixOSTest {
  name = "desktop-convert";
  globalTimeout = 1200;
  defaults.documentation.enable = false;

  # Stands in for the installer USB stick. Its second disk is the desktop's disk.
  nodes.installer = {
    virtualisation.emptyDiskImages = [ 6144 ];
    virtualisation.memorySize = memoryMiB;
    environment.systemPackages = [
      pkgs.gptfdisk
      pkgs.dosfstools
      pkgs.cryptsetup
      pkgs.btrfs-progs
    ];
    environment.etc."install/generic".source = generic;
  };

  testScript = ''
    import datetime
    import os
    import shutil

    disk = "/dev/vdb"
    mapper = "/dev/mapper/${luksName}"
    btrfs_opts = "compress=zstd,noatime"

    installer.start()
    installer.wait_for_unit("multi-user.target")

    with subtest("the graphical installer's layout and generic install"):
        installer.succeed(f"sgdisk -n1:0:+512M -t1:ef00 -n2:0:0 -t2:8309 {disk} && udevadm settle")
        installer.succeed(f"mkfs.vfat -F 32 -i ${espVolumeId} {disk}1")
        installer.succeed(
            f"printf '%s' '${passphrase}' | cryptsetup -q luksFormat --type luks2 --uuid ${luksUuid} {disk}2 -"
            f" && printf '%s' '${passphrase}' | cryptsetup open --key-file - {disk}2 ${luksName}"
        )
        installer.succeed(f"mkfs.btrfs -q -U ${btrfsUuid} {mapper}")
        installer.succeed(
            f"mkdir /mnt && mount -o {btrfs_opts} {mapper} /mnt"
            " && btrfs subvolume create /mnt/home && btrfs subvolume create /mnt/nix"
            f" && mount -o subvol=home,{btrfs_opts} {mapper} /mnt/home"
            f" && mount -o subvol=nix,{btrfs_opts} {mapper} /mnt/nix"
            " && mkdir /mnt/boot && mount -o fmask=0077,dmask=0077 /dev/disk/by-uuid/${espUuid} /mnt/boot"
        )
        installer.succeed("nixos-install --root /mnt --system /etc/install/generic --no-root-passwd --no-channel-copy >&2")
        installer.succeed("umount -R /mnt && cryptsetup close ${luksName}")
        installer.shutdown()

    vars = os.path.join(installer.state_dir, "OVMF_VARS.fd")
    shutil.copy("${pkgs.OVMF.variables}", vars)
    os.chmod(vars, 0o644)
    desktop = create_machine(
        start_command=" ".join([
            "${pkgs.qemu_test}/bin/qemu-kvm", "-cpu", "max", "-m", "${toString memoryMiB}",
            "-drive", "if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}",
            "-drive", f"if=pflash,format=raw,unit=1,file={vars}",
            "-drive", f"file={installer.state_dir}/empty0.qcow2,id=drive1,if=none,index=1,werror=report",
            "-device", "virtio-blk-pci,drive=drive1",
        ]),
        name="desktop",
    )
    driver.machines.append(desktop)

    def boot():
        desktop.start()
        # The scripted initrd asks "Passphrase for ...", the systemd one
        # "Please enter passphrase for disk ...".
        desktop.wait_for_console_text("assphrase for", timeout=datetime.timedelta(minutes=2))
        desktop.send_console("${passphrase}\n")
        desktop.wait_for_unit("multi-user.target")

    def as_alice(cmd):
        return desktop.succeed(f"su alice -c '{cmd}'")

    # The test driver's cleanup doesn't stop a VM started this way, and the
    # build waits for it, so stop it here whatever happens.
    try:
        with subtest("the generic system boots from the btrfs top level and gets used"):
            boot()
            desktop.succeed("findmnt -n -o FSTYPE,FSROOT / | grep -x 'btrfs /'")
            as_alice("mkdir -p ~/Documents && echo report > ~/Documents/report && echo scratch > ~/scratch")
            desktop.succeed("mkpasswd -m yescrypt '${passphrase}' > /alice.hash")
            machine_id = desktop.succeed("cat /etc/machine-id")
            alice_uid = desktop.succeed("id -u alice")

        with subtest("convert: nixos-rebuild boot into the ephemeral-root system"):
            # What `nixos-rebuild boot --flake .#desktop` does with the built system.
            desktop.succeed(
                "nix-env -p /nix/var/nix/profiles/system --set $(readlink -f /etc/converted)"
                " && /nix/var/nix/profiles/system/bin/switch-to-configuration boot"
            )
            desktop.shutdown()

        with subtest("the converted system: tmpfs root, existing state kept"):
            boot()
            desktop.succeed("findmnt -n -o FSTYPE / | grep -x tmpfs")
            desktop.succeed("findmnt -n -o FSTYPE,FSROOT /persist | grep -x 'btrfs /'")
            desktop.succeed("findmnt -n -o FSTYPE,FSROOT /nix | grep -x 'btrfs /nix'")
            assert desktop.succeed("cat /etc/machine-id") == machine_id, "machine-id changed"
            assert desktop.succeed("id -u alice") == alice_uid, "alice's UID changed"
            assert as_alice("cat ~/Documents/report").strip() == "report"
            desktop.succeed("test ! -e /home/alice/scratch")
            desktop.succeed("test -e /persist/home/alice/scratch")
            desktop.shutdown()

        with subtest("the converted system shut down without failing to unmount"):
            boot()
            desktop.succeed("findmnt -n -o FSTYPE / | grep -x tmpfs")
            previous = desktop.succeed("journalctl -b -1 -o cat")
            # The kept journal must cover that boot's shutdown for the absence
            # of the message to mean anything.
            assert "Journal stopped" in previous, "the previous boot's shutdown is not in the journal"
            assert "Failed unmounting" not in previous, "the previous shutdown failed to unmount a filesystem"

        with subtest("the previous generation still boots the old root"):
            entry = desktop.succeed("grep -l '^version Generation 1 ' /boot/loader/entries/*.conf").strip()
            desktop.succeed(f"bootctl set-oneshot {os.path.basename(entry)}")
            desktop.shutdown()
            boot()
            desktop.succeed("findmnt -n -o FSTYPE,FSROOT / | grep -x 'btrfs /'")
            assert as_alice("cat ~/scratch").strip() == "scratch"
    finally:
        desktop.crash()
  '';
}
