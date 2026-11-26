# nix-config

Personal NixOS + Home Manager configuration, built with
[flake-parts](https://flake.parts). Every `.nix` file under `modules/`,
`profiles/` and `globals/` is a flake-parts module, auto-discovered via
[import-tree](https://github.com/vic/import-tree), so adding a file is enough
to wire it in.

## Layout

| Path | What it holds |
| --- | --- |
| `globals/` | Flake-wide facts every config can read: `identity` (owner's name, email, public keys) and `tailnet` (each host's MagicDNS name, e.g. `config.tailnet.cedrus`). |
| `modules/` | Reusable features, grouped by area (`cli/`, `desktop/`, `dev/`, ...). Each file defines `flake.modules.nixos.<name>`, `flake.modules.homeManager.<name>` or `flake.modules.generic.<name>`, and knows nothing about a specific host or person. |
| `profiles/hosts/<host>/` | One directory per machine. `default.nix` lists the modules the host uses; the other files hold its host-specific settings. |
| `profiles/users/` | Login accounts (`yuxqiu`, `snowflake`), included by the hosts that have them. |
| `profiles/configs/` | The plumbing that turns `configurations.nixos` into flake outputs, apps and checks. |
| `packages/` | Small personal tools, packaged for use across hosts. |
| `tests/` | NixOS VM tests (run as flake checks). |

## Reusing this config

**Copy a module.** Each file under `modules/` is self-contained and readable
on its own. When copying one, check what it reads from outside itself:

- `config.identity` / `config.tailnet`: defined in `globals/`. Replace them
  with your own values.
- `inputs.*` (captured from the outer function) and `mv` (pinned package
  versions, passed as a special argument): flake inputs of this repo, see
  `flake.nix`.
- Options without a default (e.g. `programs.geminicommit.configFile`): the
  module expects your config to set them.
- `persistence.directories` / `persistence.files`: the state the module keeps
  on hosts whose root is wiped at boot (`modules/security/impermanence.nix`;
  see [docs/impermanence.md](docs/impermanence.md)). Without that module they do nothing;
  drop them if you copy the module elsewhere.

The modules are also exported as flake outputs (`modules.nixos.<name>`,
`modules.homeManager.<name>`), but they assume this flake's `generic.base`,
which carries the owner's identity, so copying is usually simpler.

**Fork it for your own machines.**

Each host is one directory:

```text
profiles/hosts/cedrus/
├── default.nix        # the modules cedrus uses, system and Home Manager
├── git.nix            # cedrus's settings for one module or service
├── tailscale.nix
└── ...
```

1. Put your name, email and public keys in `globals/identity.nix`, and your
   hosts' MagicDNS names in `globals/tailnet.nix`. Without Tailscale, leave
   `tailnet` empty: the modules handle that (you just get no SSH host
   aliases), but host files that address a host by name (e.g.
   `profiles/hosts/cedrus/paseo.nix`) fail evaluation until you adapt or
   drop them.
2. Replace the accounts in `profiles/users/` and the host directories in
   `profiles/hosts/` (start from the closest one: `cedrus` for a desktop,
   `dracaena` for a headless server). Each host needs its own
   `_hardware-configuration.nix` (see below).
3. Secrets: the encrypted files are only readable with the owner's keys.
   Replace the keys in `.sops.yaml`, delete the `secrets/` files and create
   your own (see *Setting up a machine*). Drop the private `nix-secrets` input
   from `flake.nix`; only `profiles/hosts/dracaena/xray.nix` reads it.
4. Build-check, then deploy as below.

## Deploying and updating

`os-switch` and `os-update` come from `modules/nix/os.nix` (Home Manager
module `os`).

```sh
os-switch cedrus                       # build and switch locally
os-switch dracaena root@<host>         # build on and switch the remote host
os-update                              # update inputs and pinned sources
```

Arguments after the host go to `nh os switch`, e.g. `os-switch cedrus --ask`.
`os-update` runs `flake-edit follow`, `nix-update-git` for pinned fetches,
then `nix flake update`; build-check and switch afterwards.

## Setting up a machine

Secrets use [sops-nix](https://github.com/Mic92/sops-nix) with
post-quantum age keys. Each host has its own key, made and granted access
before the host first runs its config, so it decrypts its secrets from the
first boot. An admin key kept in Proton Pass grants access.

1. Describe the host:
   - `profiles/hosts/<host>/default.nix` with `configurations.nixos.<host>`
     (start from `cedrus` or `dracaena`), including the accounts it needs
     from `profiles/users/`, and set `networking.hostName`.
   - A new account goes in `profiles/users/<account>.nix`; it logs in with
     the keys in `globals/identity.nix` (add a key there if it needs a new
     one).
   - Add the host to `globals/tailnet.nix`:
     `<host> = "<hostName>.<tailnet>.ts.net";`. The MagicDNS name follows
     `networking.hostName`, not the flake output name (dracaena is
     `snowflake`). SSH aliases (`ssh <host>`) and services that address
     each other use it.
2. Add a `.sops.yaml` rule for `profiles/hosts/<host>/secrets/<host>.yaml`
   listing only the admin key, then create the file with
   `sops-update admin <file>`. If the host joins the tailnet, put a Tailscale
   auth key in it as `tailscale_key` (read by the host's `tailscale.nix`, as
   in `profiles/hosts/cedrus/tailscale.nix`). `git add` everything.
3. Install:
   - **Remote, wipe and install:** `os-install <host> root@<ip>`. It makes
     the host's key on a tmpfs here, grants it access to the secrets file,
     and nixos-anywhere copies it onto the new system; it also writes
     `_hardware-configuration.nix` on first use. A reinstall replaces the
     host's previous key; a failed install restores `.sops.yaml` and the
     secrets file. Commit both afterwards.
   - **Already running NixOS** (e.g. fresh from the graphical installer):
     in a checkout of this repository on that machine, run
     `nix --extra-experimental-features 'nix-command flakes' develop .#bootstrap`,
     which provides the tools and prints the steps. `os-bootstrap <host>`
     makes and grants the key, copies the hardware configuration, and lists
     secrets still missing (such as password hashes); rerun it until it says
     *Ready*, then run the `nixos-rebuild boot` command it prints and reboot.

A host with impermanence (root on tmpfs) has a recommended disk layout and two
extra setup steps: see [docs/impermanence.md](docs/impermanence.md).

## Hosts

- `cedrus`: desktop, root on tmpfs. See [docs/cedrus.md](docs/cedrus.md).
- `dracaena`: headless server for coding agents. See
  [docs/dracaena.md](docs/dracaena.md).
