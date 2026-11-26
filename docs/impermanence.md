# Impermanence

A host that includes `nixos.impermanence` (`modules/security/impermanence.nix`)
has `/` on a tmpfs, empty at every boot. Only paths listed in `persistence`
survive; they are bind-mounted from a persistent filesystem at the same paths.
Each module lists the state it needs (e.g. `nm.nix` keeps saved networks,
`firefox.nix` the profile); host-only data (documents, the dotfiles checkout)
goes in the host's own `persistence.nix`. Hosts using it: `cedrus`
([docs/cedrus.md](cedrus.md)).

## How a boot goes

1. The initrd mounts the tmpfs as `/`, the persistent filesystem, and `/nix`.
2. Activation recreates users and groups from the config (UIDs from the kept
   `/var/lib/nixos`), decrypts secrets with the host key read straight from
   the persistent filesystem, and builds `/etc`. The module then moves content
   of newly listed paths onto the persistent filesystem (see below) and
   impermanence creates missing kept directories there.
3. systemd bind-mounts every kept path (directories as `.mount` units, files
   as `persist-*` services).
4. Home Manager's own boot service re-links every file it manages into the
   empty home. That is why Home Manager configs need no keeping.

## Recommended disk layout

For a new machine, use one btrfs partition (inside LUKS: the persistent
filesystem holds every kept secret) with separate subvolumes mounted directly,
and the tmpfs as `/`:

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

Why separate mounts: when `/nix` is a bind mount of a directory on the
persistent filesystem (the only way to share one ext4 partition), `nix.mount`
requires the persistent filesystem's mount. systemd stops that mount at
shutdown, the stop propagates to `/nix` and `/nix/store`, and the busy store
logs "Failed unmounting /nix/store" on every shutdown. It is harmless (the
store is remounted read-only at the end), but separate subvolumes or partitions
have no such dependency. Separate partitions work too; subvolumes share one
pool of free space.

A machine converted in place keeps its old root as the persistent filesystem
and binds `/nix` from it (as `cedrus` does), and so shows that message.

## Opting in

A host includes `nixos.impermanence` and sets, in its own directory:

- the persistent filesystem's mount (and `/nix`) and `persistence.storage`
  (its mount point);
- `sops.age.keyFile` on that filesystem: secrets are installed during
  activation, before kept directories are bind-mounted;
- a `hashedPasswordFile` per login user, from a sops secret with
  `neededForUsers = true`. Users are immutable (`users.mutableUsers = false`),
  so `passwd` changes do not survive; change the hash in sops instead.

## Keeping something new

Add its path to the owning module and apply with `nh os switch` (not `boot`):
the switch moves the current content onto the persistent filesystem before
mounting it. With `boot`, the content lives only on the tmpfs and is gone at
the reboot. Restart the app afterwards; files it still has open point at the
old copy.

One case is not captured: newly keeping a directory that contains an
already-kept one. Say `.local/share/app/models` is kept and you add
`.local/share/app`. The persistent filesystem already has `.local/share/app`
(as the parent of `models`), so the switch treats it as kept and mounts it
over the live directory, hiding the files the app wrote next to `models`
(they are lost at the reboot). Before such a switch, copy those files over
yourself, for example
`cp -a ~/.local/share/app/settings.json <storage>/home/<user>/.local/share/app/`
(the user owns their directory on the storage; system paths need `sudo`).

Keep a directory rather than a single file when the app saves by writing a new
file and renaming it over the old one (zsh history, GTK bookmarks): a kept file
is a bind mount, which a rename cannot replace. Kept files are also not hidden
from file managers, unlike kept directories.

`nix build .#checks.<system>.impermanence` (e.g. `x86_64-linux`) runs a VM
test of the module; it needs a Linux machine with KVM, or a Linux builder.

## Setting up an impermanent machine

Follow the README's *Setting up a machine*. Two things differ:

- Its users' passwords come from sops, so put each `<user>-password` hash
  (`mkpasswd -m yescrypt`) in the secrets file before the first boot;
  `os-bootstrap` stops and lists any that are missing.
- The host's config must already declare its persistent filesystem
  (`fileSystems.<storage>`, `persistence.storage`, `sops.age.keyFile` on it),
  and that filesystem must be mounted when `os-bootstrap` runs: it puts the
  key wherever the filesystem is mounted now. On a machine converted in place
  that is `/` (the running root becomes the persistent filesystem, so
  `/disk/var/lib/sops-nix/key.txt` is written as `/var/lib/sops-nix/key.txt`);
  with the recommended layout it is wherever you mounted `@persist`. It stops
  if the filesystem is not mounted. Enable disk encryption in the installer.
- Install with `nh os boot . -H <host>` and reboot. On a machine converted in
  place, the previous generation in the boot menu still boots from the
  persistent filesystem as its root. Afterwards, use the key's path under
  the persistent filesystem with `sops-update-key`.
