# nix-config

Personal NixOS and Home Manager configuration, built with
[flake-parts](https://flake.parts). Every `.nix` file under `modules/`,
`profiles/`, and `globals/` is a flake-parts module.
[import-tree](https://github.com/vic/import-tree) discovers them, so adding a
file is enough to wire it in.

## Layout

| Path | What it holds |
| --- | --- |
| `globals/` | Flake-wide facts every config can read: `identity` (owner's name, email, public keys) and `tailnet` (each host's MagicDNS name, as `config.tailnet.<host>`). |
| `modules/` | Reusable features, grouped by area (`cli/`, `desktop/`, `dev/`, ...). Each file defines `flake.modules.nixos.<name>`, `flake.modules.homeManager.<name>` or `flake.modules.generic.<name>`, and knows nothing about a specific host or person. |
| `profiles/hosts/<host>/` | One directory per machine. `default.nix` lists the modules the host uses; the other files hold its host-specific settings. |
| `profiles/users/` | Login accounts, included by the hosts that have them. |
| `flake/` | The plumbing that turns `configurations.nixos` into flake outputs and checks, and builds `packages/`. Every host gets `generic.base`, its `_hardware-configuration.nix` and its secrets file `secrets/<host>.yaml` from here. |
| `packages/` | Small personal tools and host-only builds. Each `packages/<name>.nix` is flake package `<name>`; modules use `inputs.self.packages.${system}.<name>`. |
| `tests/` | NixOS VM tests (run as flake checks). |

## Reusing this config

### Copy a module

Each file under `modules/` is self-contained and readable on its own. When you
copy one, check what it reads from outside itself:

| What it reads | Where it comes from | What to do |
| --- | --- | --- |
| `config.identity`, `config.tailnet` | `globals/` | Replace them with your own values. |
| `inputs.*` (captured from the outer function) and `mv` (pinned package versions, passed as a special argument) | Flake inputs of this repo | See `flake.nix`. |
| Options without a default (for example, `programs.geminicommit.configFile`) | Your config | Set them. |
| `persistence.directories`, `persistence.files` | `modules/base/ephemeral-root.nix` | These list the state the module keeps on hosts whose root is wiped at boot ([docs/ephemeral-root.md](docs/ephemeral-root.md)). Without that module they do nothing. Drop them if you copy the module elsewhere. |

### Fork it for your own machines

Each host is one directory:

```text
profiles/hosts/<host>/
├── default.nix        # the modules the host uses, system and Home Manager
├── git.nix            # the host's settings for one module or service
├── tailscale.nix
└── ...
```

1. Put your name, email, and public keys in `globals/identity.nix`.
2. Put your hosts' MagicDNS names in `globals/tailnet.nix`.

   Without Tailscale, leave `tailnet` empty: you get no SSH host aliases, and
   host files that address a host by name need adapting.
3. Replace the accounts in `profiles/users/`.
4. Replace the host directories in `profiles/hosts/`. Start from the closest
   one (see [Hosts](#hosts) for each one's role). Each host
   needs its own `_hardware-configuration.nix` (see
   [Setting up a machine](#setting-up-a-machine)).
5. Replace the secrets. Only the owner's keys can read the encrypted files.
   1. Replace the keys in `.sops.yaml`.
   2. Delete the `secrets/` files and create your own (see
      [Setting up a machine](#setting-up-a-machine)).
   3. Drop the private `nix-secrets` input from `flake.nix`, and adapt or
      drop the host files that read it.
6. Build-check, then deploy as described in
   [Deploying and updating](#deploying-and-updating).

## Deploying and updating

`os-switch` and `os-update` come from `modules/nix/os.nix` (Home Manager
module `os`).

```sh
os-switch <host>                       # build and switch locally
os-switch <host> root@<address>        # build on and switch a remote host
os-update                              # update inputs and pinned sources
```

Arguments after the host go to `nh os switch`, for example
`os-switch <host> --ask`. After `os-update`, build-check and switch.

## Setting up a machine

Adding a host, creating its secrets and installing it, remotely with
`os-install` or locally with `os-bootstrap`:
[docs/setup.md](docs/setup.md).

## Hosts

- `cedrus`: desktop, root on tmpfs. See [docs/cedrus.md](docs/cedrus.md).
- `dracaena`: headless server for coding agents, root on tmpfs. See
  [docs/dracaena.md](docs/dracaena.md).
