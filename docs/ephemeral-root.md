# Ephemeral root

A host that includes `nixos.ephemeral-root` (`modules/base/ephemeral-root.nix`)
has `/` on a tmpfs, which is empty at every boot. Only the paths listed in
`persistence` survive. They are kept on a persistent filesystem and
bind-mounted at the same paths by
[preservation](https://github.com/nix-community/preservation).

Two places list kept paths:

- Each module lists the state it needs. For example, `nm.nix` keeps saved
  networks, and `firefox.nix` keeps the profile.
- The host's own `persistence.nix` lists host-only data, such as documents and
  the dotfiles checkout.

Hosts using it: `cedrus` ([docs/cedrus.md](cedrus.md)) and `dracaena`
([docs/dracaena.md](dracaena.md)).

To set up a machine with an ephemeral root, follow
[*Setting up a machine*](../README.md#setting-up-a-machine) in the README. It
covers both install routes: a remote host laid out by disko, and a desktop
from the graphical installer converted in place.

## How a boot goes

1. The initrd mounts the tmpfs as `/`, the persistent filesystem, and `/nix`.
   It also bind-mounts the kept paths that activation reads (`inInitrd`):
   `/etc/machine-id`, `/var/lib/nixos` and `/var/lib/sops-nix`.
2. Activation, still in the initrd, does the following:
   1. It decrypts the secrets needed for users (password hashes) with the
      host key at `/var/lib/sops-nix/key.txt`.
   2. It recreates users and groups from the config. UIDs come from
      `/var/lib/nixos`.
   3. It installs the other secrets and builds `/etc`.
   4. Then the module moves the content of newly listed paths onto the
      persistent filesystem (see [Keeping something new](#keeping-something-new)).
3. systemd bind-mounts the other kept paths. These are `.mount` units, before
   `sysinit.target`. A missing source directory is created by systemd.
4. systemd-tmpfiles sets each kept path's declared owner and mode, on both
   sides of the mount (see [Owner and mode](#owner-and-mode)).
5. Home Manager's own boot service re-links every file it manages into the
   empty home. That is why Home Manager configs need no keeping.

A path that activation reads must be mounted in the initrd: set
`inInitrd = true` on its entry.

## Opting in

A host includes `nixos.ephemeral-root` and sets the following in its own
directory:

| Setting | Why |
| --- | --- |
| The persistent filesystem's mount (and `/nix`), and `persistence.storage` (its mount point) | Kept paths are bind-mounted from there. |
| A `hashedPasswordFile` per login user, from a sops secret with `neededForUsers = true` | Users are immutable (`users.mutableUsers = false`), so `passwd` changes do not survive. Change the hash in sops instead. |

## Recommended disk layout

For a machine laid out by disko (a server installed with `os-install`), use
one btrfs partition with separate subvolumes mounted directly, and the tmpfs
as `/`. Put the partition inside LUKS: the persistent filesystem holds every
kept secret. The exception is a machine nobody can unlock at boot, such as a
cloud VM without SSH in the initrd or a virtual TPM (`dracaena`).

| Mount | Source | Notes |
| --- | --- | --- |
| `/` | tmpfs | set by the module |
| `/nix` | subvolume `@nix` | the store; no need to keep anything here |
| `/persist` | subvolume `@persist` | `persistence.storage`; `neededForBoot = true` |
| `/boot` | EFI partition | |

```nix
fileSystems."/nix" = {
  device = "/dev/mapper/<luks-name>";
  fsType = "btrfs";
  options = [ "subvol=@nix" "noatime" ];
};
fileSystems."/persist" = {
  device = "/dev/mapper/<luks-name>";
  fsType = "btrfs";
  options = [ "subvol=@persist" "noatime" ];
  neededForBoot = true;
};
persistence.storage = "/persist";
```

Separate partitions work too. Subvolumes share one pool of free space.

### Why `/nix` is a separate mount

The alternative is to make `/nix` a bind mount of a directory on the
persistent filesystem. That is the only way to share one ext4 partition.
Then:

1. `nix.mount` requires the persistent filesystem's mount.
2. systemd stops that mount at shutdown.
3. The stop propagates to `/nix` and `/nix/store`.
4. The store is busy, so every shutdown logs "Failed unmounting /nix/store".

The message is harmless: the store is remounted read-only at the end. Separate
subvolumes or partitions have no such dependency.

A machine converted in place whose old root holds `/nix` as a plain directory
binds `/nix` from it (as `cedrus` does), and so shows that message.

### A desktop from the graphical installer

A desktop from the graphical installer gets the same property without
repartitioning:

- `/nix` stays the installer's `nix` subvolume.
- The btrfs top level (the old root) is mounted at `/persist`.
- The installer's `home` subvolume is not mounted on its own. It is a nested
  subvolume, so it appears as the directory `/persist/home`, and kept home
  paths are bind-mounted from it.

A btrfs snapshot of the top level does not include nested subvolumes. If you
use snapshots, snapshot `home` separately.

## Owner and mode

systemd-tmpfiles sets every kept path to its declared owner and mode at every
boot, whatever is on disk. Undeclared means owned by root (or by the user, for
a Home Manager path) with mode 0755 for a directory and 0644 for a file. A
missing parent of a Home Manager path is created with the user as owner and
mode 0755.

So an entry whose path is not that declares it, for example:

```nix
persistence.directories = [
  {
    directory = "/var/lib/lockdown";
    inherit (config.services.usbmuxd) user group;
    mode = "2775";
  }
];
```

Take the owner and mode from upstream where it is exposed: a NixOS option
(`services.usbmuxd.user`) or the unit's settings in the NixOS config
(`config.systemd.services.acme-setup.serviceConfig.StateDirectoryMode`).

When the program sets the directory's mode itself every time it starts, use
`mode = config.persistence.programSetsMode;`. It is tmpfiles' create-only form
(`":0700"`), which never changes an existing directory. systemd has already
created the directory when mounting it, so the program's own mode is the only
one applied, and nothing is left to drift from upstream. systemd does this for a unit's `StateDirectory=` and
`CacheDirectory=` (it re-applies `StateDirectoryMode=` at every start), and
usbmuxd does it for `/var/lib/lockdown`.

## Keeping something new

1. Add the path to the module that owns it.
2. Apply with `nh os switch`, not `boot`. The switch moves the current content
   onto the persistent filesystem before mounting it. With `boot`, the content
   lives only on the tmpfs and is gone at the reboot.
3. Restart the app. Files it still has open point at the old copy.

### Keeping a parent of a kept directory

The switch does not capture one case: newly keeping a directory that contains
an already-kept one.

Say `.local/share/app/models` is kept and you add `.local/share/app`:

1. The persistent filesystem already has `.local/share/app`, as the parent of
   `models`.
2. So the switch treats it as kept and mounts it over the live directory.
3. That hides the files the app wrote next to `models`. They are lost at the
   reboot.

Before such a switch, copy those files over yourself. For example:

```sh
cp -a ~/.local/share/app/settings.json <storage>/home/<user>/.local/share/app/
```

The user owns their directory on the storage. System paths need `sudo`.

### Keeping a file or its directory

Keep a directory rather than a single file when the app saves by writing a
new file and renaming it over the old one (zsh history, GTK bookmarks). A kept
file is a bind mount, which a rename cannot replace.

## Testing the module

`nix build .#checks.<system>.ephemeral-root` (for example, `x86_64-linux`) runs a
VM test of the module. It needs a Linux machine with KVM, or a Linux builder.
