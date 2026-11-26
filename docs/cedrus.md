# cedrus

Desktop: NixOS + [niri](https://github.com/YaLTeR/niri) +
[dux-shell](https://github.com/duxlabs-dev/dux-shell). Account `yuxqiu`.
Host files: `profiles/hosts/cedrus/`.

## Impermanence

`/` is a tmpfs; how it works, keeping new paths and setting up another
machine are in [docs/impermanence.md](impermanence.md). Host-only kept paths
(documents, the dotfiles checkout, the Gurobi license in `/opt/gurobi`) are in
`profiles/hosts/cedrus/persistence.nix`.

`cedrus` was converted in place: its old ext4 root is the persistent
filesystem, mounted at `/disk`, and `/nix` is a bind mount of `/disk/nix`, so
nothing moved. That layout differs from the recommended one: every shutdown
logs a harmless "Failed unmounting /nix/store" (the reason is in the comment
on `/nix` in `persistence.nix`). Moving to separate btrfs subvolumes would
mean migrating the whole disk, so it waits for a reinstall.

## Device quirks

Hardware/OS-specific fixes that don't belong in the Nix config itself.

**Keyboard**
- [Connecting a Sofle over Bluetooth (BT_CLR)](https://www.reddit.com/r/ErgoMechKeyboards/comments/1j4k8gy/my_nicenano_sofle_wont_connect_via_bluetooth/)
- [Pairing a Logitech K380 via `bluetoothctl`](https://unix.stackexchange.com/questions/590221/pairing-logitech-k380-in-ubuntu-20-04)