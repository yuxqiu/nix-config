# nix-config

Personal NixOS + Home Manager configuration, built with
[flake-parts](https://flake.parts). Module files under `modules/` and
`profiles/` are auto-discovered via [import-tree](https://github.com/vic/import-tree),
so adding a file is enough to wire it in.

## Structure

- `modules/`: reusable building blocks (`flake.modules.nixos.*`,
  `flake.modules.homeManager.*`, `flake.modules.generic.*`).
- `profiles/hosts/`: one directory per machine, wiring together the
  modules each one needs.
- `profiles/configs/`, `profiles/options/`: the flake-parts plumbing that
  turns `configurations.nixos` into real flake outputs.
- `packages/`: small personal tools and scripts, packaged for use across
  hosts.

## Usage

```sh
nixos-rebuild switch --flake .#<host>
```

## Hosts

- `cedrus`: desktop, NixOS + [niri](https://github.com/YaLTeR/niri) +
  [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell).
- `dracaena`: headless cloud server, aarch64, provisioned
  declaratively via [disko](https://github.com/nix-community/disko) +
  [nixos-anywhere](https://github.com/nix-community/nixos-anywhere).

## Device Quirks

Hardware/OS-specific fixes that don't belong in the Nix config itself.

**Keyboard**
- [Connecting a Sofle over Bluetooth (BT_CLR)](https://www.reddit.com/r/ErgoMechKeyboards/comments/1j4k8gy/my_nicenano_sofle_wont_connect_via_bluetooth/)
- [Pairing a Logitech K380 via `bluetoothctl`](https://unix.stackexchange.com/questions/590221/pairing-logitech-k380-in-ubuntu-20-04)