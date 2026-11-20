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

## Setting up a machine

Secrets use [sops-nix](https://github.com/Mic92/sops-nix) with
post-quantum age keys. Each host generates its own key on first
activation; an admin key kept in Proton Pass grants it access.

1. Add `profiles/hosts/<host>/` and a `.sops.yaml` rule for
   `profiles/hosts/<host>/secrets/<host>.yaml` listing only the admin key,
   then create the file with `sops-update admin <file>`. `git add` them.
2. Install:
   - **Remote, wipe and install:** `os-install <host> root@<ip>`
     (nixos-anywhere; writes `_hardware-configuration.nix` on first use).
   - **Already running NixOS:** copy its `hardware-configuration.nix` to
     `_hardware-configuration.nix`, then
     `sudo nixos-rebuild switch --flake .#<host> --extra-experimental-features 'nix-command flakes'`.
3. Grant the new key and redeploy:
   `sops-update-key add admin <user>@<host>:/var/lib/sops-nix/key.txt <file>`,
   then `os-switch <host> [<user>@<host>]`.

Until step 3, everything except services that read secrets works.

## Hosts

- `cedrus`: desktop, NixOS + [niri](https://github.com/YaLTeR/niri) +
  [DankMaterialShell](https://github.com/duxlabs-dev/dux-shell).
- `dracaena`: headless cloud server, aarch64, provisioned
  declaratively via [disko](https://github.com/nix-community/disko) +
  [nixos-anywhere](https://github.com/nix-community/nixos-anywhere).

## Device Quirks

Hardware/OS-specific fixes that don't belong in the Nix config itself.

**Keyboard**
- [Connecting a Sofle over Bluetooth (BT_CLR)](https://www.reddit.com/r/ErgoMechKeyboards/comments/1j4k8gy/my_nicenano_sofle_wont_connect_via_bluetooth/)
- [Pairing a Logitech K380 via `bluetoothctl`](https://unix.stackexchange.com/questions/590221/pairing-logitech-k380-in-ubuntu-20-04)