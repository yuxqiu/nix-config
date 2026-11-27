# Threat model

This document says what the hosts in this flake defend against, what they
accept, and where the line between trusted and untrusted code is. The
principles apply to every host. The host sections say how each host applies
them.

| Host | Role |
| --- | --- |
| **cedrus** | The desktop. |
| **dracaena** | A headless cloud server that runs coding agents. It is reachable from the internet. |

## Trust line

The line is how code arrives, not whether it is malicious.

**Trusted: software the flake installs, and the state it keeps.**

- This software is pinned and comes from nixpkgs or chosen sources.
- It changes only by an update that shows up as a diff.
- Examples: apps, shells, the compositor and desktop shell, and Home Manager
  CLI tools.
- Trusted means well-intentioned, not unbreakable (see *Exploited trusted
  software*).
- A program's kept state (settings, plugins, profiles) is trusted with the
  program (see *Owner responsibilities*).

**Untrusted: everything else.** In particular:

- Nix packages the flake does not install (`nix run nixpkgs#…`,
  `nix shell`, other flakes).
- Package managers (`npm`, `pnpm`, `pip`/`uv`, `cargo`, `go`) and the
  install and build scripts they run.
- A project's own scripts and tests, especially in repositories written by
  someone else.
- Downloaded binaries, `curl | sh`, and games.
- Commands a coding agent runs after it reads untrusted content (web pages,
  issues, repository files).

**Untrusted code runs isolated, never directly in the user's session.** It
runs in a sandbox, container, or VM, or on a machine set aside for it (see
*Server*). Containers and namespace sandboxes share the host kernel. Choose a
VM when a kernel exploit is a concern.

## Desktop (cedrus)

### Assets

- The password manager session and its local key in the kernel keyring.
- The SSH keys, against unauthorized use.
- Browser sessions and cookies.
- API keys and other secrets.

### Goals

**Met: code running as the user cannot become root without
authentication.**

- No group is root-equivalent (Docker is rootless).
- Only root is a trusted Nix user.
- Attaching a disk image as a loop device needs admin authentication.

**Met: code running as the user cannot change how the machine connects
without admin authentication.**

- The user is not in `networkmanager`.
- Creating or editing any NetworkManager profile needs admin authentication.
  Profiles are kept, and a profile can carry DNS, a VPN, or a proxy.
- `resolvectl` also needs admin authentication.
- Connecting to saved profiles does not.

**Met: what code running as the user leaves outside kept paths is gone at the
next reboot.**

- `/` is a tmpfs, so the following do not survive: autostart entries,
  `environment.d`, user units, the user Nix profile, and the session
  environment.
- Home Manager re-creates its dotfiles at every boot.

**Met: the application firewall fails closed.**

- OpenSnitch denies unmatched connections whenever its UI is not answering.
- It is not a boundary against code running as the user, because that code
  can stop the UI.

**Accepted: kept paths are writable by the user.**

- What code running as the user changes in kept paths survives reboots.
- Several kept paths hold state that runs code or picks routes: agent
  settings and plugins, the Firefox profile, Flatpak apps, Steam games, and
  Docker images. That state is trusted with its program (see *Owner
  responsibilities*).
- Kept paths are narrowed to data where that is cheap, as for ssh
  (`known_hosts` only).

### Exploited trusted software

Hostile input can still break trusted software. Two things matter: how much
untrusted input an app parses, and whether the app has its own sandbox.

- Browsers rely on their own sandbox.
- Not hardened yet. Candidates if exposure grows:
  - always-connected proprietary apps (chat, video calls);
  - apps that accept files from the network;
  - viewers for downloaded documents and images.

### Owner responsibilities

- **Review deployments.** Every host applies the configuration repository as
  root. A change that any process writes into the repository becomes root on
  the next deploy. The owner checks the diff before deploying.
- **Vet what is installed and kept.** Installed programs and their kept state
  are trusted together.
  - By design, many programs run code or choose network routes from their own
    state: agent hooks and MCP servers, browser extensions and proxy
    settings, and plugins.
  - Anything running as the user can change that state.
  - The owner decides which programs to install and what state to keep for
    them. The owner checks that state when something untrusted may have
    reached it.
- **Isolate untrusted code.** Per the trust line, untrusted code goes into a
  sandbox, container, or VM, chosen for how hostile the code may be. Code run
  in a normal shell gets everything the user can reach, including the assets.

## Server (dracaena)

### Exposure

| Where | What |
| --- | --- |
| Internet | SSH: key-only, with passwords and keyboard-interactive off. Root can log in with the owner's key. |
| Internet | The ports that a proxy server and its certificate renewal use. |
| Tailnet | The agent web UI, served only there. |

### Assets

- The proxy server's configuration (its client credentials).
- The host's tailnet membership (its auth key).
- The two items above are sops secrets owned by root. The agent account
  cannot read them.
- The coding agents' provider logins in the agent account's home.
- Work in progress in the agent account.

### How untrusted input is contained

The account and the machine isolate agent-run commands.

- Agents run as `snowflake`: key-only login, no sudo, and no Git hosting
  credentials.
- Work leaves the server only when the desktop fetches it over the tailnet.
  Nothing is pushed from the server.
- Inside that account, agent-run commands can read the provider logins and
  the work in progress. This risk is accepted, so nothing else of value is
  kept there.
- When the desktop fetches work, it pulls Git objects, not configuration or
  hooks. The owner reviews the work before running or merging it.

### Accepted risks

- The agent account's kept state (agent logins, Paseo data) survives reboots
  like any kept state. Everything else a hijacked agent leaves is gone at the
  next reboot (root on tmpfs). On this server, reboots are rare.
- A compromised agent account can reach whatever the tailnet lets dracaena
  reach, including services on the desktop. Tailnet access rules are managed
  outside this flake.
- A local privilege escalation (kernel exploit) from the agent account gets
  root on the server. With root come the proxy credentials and the tailnet
  identity.
- For vulnerabilities in the internet-facing services (SSH, the proxy), the
  only mitigation is to keep the services updated and key-only.

## Out of scope (accepted, all hosts)

- A compromised package or flake input that the flake installs. Packages that
  the flake does not install are untrusted (see *Trust line*).
- Anything already running as root.
- Physical access. USB device allow-listing covers part of it. The desktop's
  root is a tmpfs, but its persistent filesystem (`/disk`, which holds every
  kept path) is not encrypted.
- Malware already running as the user with persistence.
