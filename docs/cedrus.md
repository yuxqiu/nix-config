# cedrus

| | |
| --- | --- |
| Role | Desktop |
| Stack | NixOS, [niri](https://github.com/YaLTeR/niri), [dux-shell](https://github.com/duxlabs-dev/dux-shell) |
| Account | `yuxqiu` |
| Host files | `profiles/hosts/cedrus/` |

## Impermanence

`/` is a tmpfs. [docs/impermanence.md](impermanence.md) explains how it
works and how to keep new paths; the README's
[*Setting up a machine*](../README.md#setting-up-a-machine) covers setting up
another one.

Host-only kept paths are in `profiles/hosts/cedrus/persistence.nix`. They
include documents, the dotfiles checkout, and the Gurobi license in
`/opt/gurobi`.

### Disk layout

`cedrus` was converted in place, so nothing moved:

- Its old ext4 root is the persistent filesystem, mounted at `/disk`.
- `/nix` is a bind mount of `/disk/nix`.

This layout differs from the recommended one. Every shutdown logs a harmless
"Failed unmounting /nix/store". The comment on `/nix` in `persistence.nix`
gives the reason. Moving to LUKS and separate btrfs subvolumes means
reformatting `/disk`'s partition and restoring it from a backup.

## Device quirks

These links cover hardware and OS fixes that do not belong in the Nix config.

**Keyboard**

- [Connecting a Sofle over Bluetooth (BT_CLR)](https://www.reddit.com/r/ErgoMechKeyboards/comments/1j4k8gy/my_nicenano_sofle_wont_connect_via_bluetooth/)
- [Pairing a Logitech K380 via `bluetoothctl`](https://unix.stackexchange.com/questions/590221/pairing-logitech-k380-in-ubuntu-20-04)
