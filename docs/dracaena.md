# dracaena

| | |
| --- | --- |
| Role | Headless cloud server that runs coding agents |
| Architecture | aarch64 |
| Provisioning | Declarative, with [disko](https://github.com/nix-community/disko) and [nixos-anywhere](https://github.com/nix-community/nixos-anywhere): `os-install dracaena root@<ip>` |
| Host files | `profiles/hosts/dracaena/` |

## Accounts

- **`snowflake`** runs the coding agents. It has key-only SSH, no sudo, and no
  Git hosting credentials. Work leaves the server only when the desktop
  fetches it over the tailnet.
- **Root** logs in over SSH with the owner's key.

## Deploy

Run `os-switch dracaena root@<host>`. The system is built on the server.

## Storage

- Root is on tmpfs (`nixos.ephemeral-root`).
- The disk holds the btrfs subvolumes `@nix` and `@persist`, with no disk
  encryption: unlocking a cloud VM at boot would need SSH in the initrd or a
  virtual TPM.
- Kept state:
  - SSH host keys;
  - the age key;
  - the ACME account and certificate;
  - the Tailscale identity;
  - the WARP registration;
  - the agent account's Paseo data and agent logins.

## Reinstall without losing state

Run this command with the server's public IP, not the `dracaena` alias:

```sh
os-install dracaena root@<public IP> --keep-state --build-on remote
```

The command does the following:

1. Copies the kept paths and the age key from the running server into memory.
2. Wipes the disk and installs.
3. Unpacks the kept paths and the age key into `/persist` before the first
   boot.

Nothing is regenerated, and `.sops.yaml` does not change. `--build-on remote`
is needed because the server is aarch64.
