# Threat model

What the hosts in this flake defend against, what they accept, and where the
line between trusted and untrusted code is drawn. The principles apply to
every host; the host sections say how each one applies them.

- **cedrus**: the desktop.
- **dracaena**: a headless cloud server, reachable from the internet, that
  runs coding agents.

## Trust line

The line is how code arrives, not whether it is malicious.

- **Trusted: software the flake installs, and the state it keeps.** Pinned,
  from nixpkgs or chosen sources, changed only by an update that shows up as
  a diff: apps, shells, the compositor and desktop shell, Home Manager CLI
  tools. Trusted means well-intentioned, not unbreakable (see *Exploited
  trusted software*). A program's kept state (settings, plugins, profiles)
  is trusted with it (see *Owner responsibilities*).
- **Untrusted: everything else**, in particular:
  - Nix packages the flake does not install (`nix run nixpkgs#…`,
    `nix shell`, other flakes).
  - Package managers (`npm`, `pnpm`, `pip`/`uv`, `cargo`, `go`) and the
    install and build scripts they run.
  - A project's own scripts and tests, especially in repositories written by
    someone else.
  - Downloaded binaries, `curl | sh`, games.
  - Commands a coding agent runs after reading untrusted content (web pages,
    issues, repository files).

**Untrusted code runs isolated, never directly in the user's session**: in a
sandbox, container or VM, or on a machine set aside for it (see *Server*).
Containers and namespace sandboxes share the host kernel; a VM is the choice
when a kernel exploit is a concern.

## Desktop (cedrus)

### Assets

- The password manager session and its local key in the kernel keyring.
- The SSH keys, against unauthorized use.
- Browser sessions and cookies.
- API keys and other secrets.

### Goals

- **Met:** code running as the user cannot become root without
  authentication: no root-equivalent group (rootless Docker), only root is a
  trusted Nix user, and attaching a disk image as a loop device needs admin
  authentication.
- **Met:** it cannot change how the machine connects without admin
  authentication: the user is not in `networkmanager`, creating or editing
  any NetworkManager profile (kept, and able to carry DNS, a VPN or a proxy)
  needs it, and so does `resolvectl`. Connecting to saved profiles does not.
- **Met:** what it leaves outside kept paths is gone at the next reboot. `/`
  is a tmpfs, so autostart entries, `environment.d`, user units, the user Nix
  profile and session environment do not survive, and Home Manager re-creates
  its dotfiles at every boot.
- **Met:** the application firewall fails closed: OpenSnitch denies
  unmatched connections whenever its UI is not answering. It is not a
  boundary against code running as the user, which can stop the UI.
- **Accepted:** kept paths are writable by the user, so what code running as
  the user changes there survives reboots. Several hold state that runs code
  or picks routes (agent settings and plugins, the Firefox profile, Flatpak
  apps, Steam games, Docker images); it is trusted with its program (see
  *Owner responsibilities*). Kept paths are narrowed to data where cheap, as
  for ssh (`known_hosts` only).

### Exploited trusted software

Trusted software can still be broken by hostile input. What matters is how
much untrusted input an app parses and whether it has its own sandbox:

- Browsers rely on their own sandbox.
- Not hardened yet; candidates if exposure grows: always-connected
  proprietary apps (chat, video calls), apps that accept files from the
  network, and viewers for downloaded documents and images.

### Owner responsibilities

- **Review deployments.** The configuration repository is applied as root on
  every host, so a change written into it by any process becomes root on the
  next deploy. The owner checks the diff before deploying.
- **Vet what is installed and kept.** Installed programs and their kept
  state are trusted together. Many programs run code or choose network routes
  from their own state by design (agent hooks and MCP servers, browser
  extensions and proxy settings, plugins), and anything running as the user
  can change that state. The owner decides which programs to install and
  what state to keep for them, and checks that state when something
  untrusted may have reached it.
- **Isolate untrusted code.** Per the trust line, untrusted code goes into a
  sandbox, container or VM chosen for how hostile it may be; running it in a
  normal shell gives it everything the user can reach, including the assets.

## Server (dracaena)

### Exposure

- From the internet: SSH (key-only, passwords and keyboard-interactive off;
  root can log in with the owner's key) and the ports used by a proxy server
  and its certificate renewal.
- On the tailnet: the agent web UI, served only there.

### Assets

- The proxy server's configuration (its client credentials) and the host's
  tailnet membership (its auth key); both are sops secrets owned by root, not
  readable by the agent account.
- The coding agents' provider logins in the agent account's home.
- Work in progress in the agent account.

### How untrusted input is contained

The isolation for agent-run commands is the account and the machine:

- Agents run as `snowflake`: key-only login, no sudo, no Git hosting
  credentials. Work leaves the box only by the desktop fetching it over the
  tailnet, never by pushing from here.
- Inside that account, agent-run commands can read the provider logins and
  the work in progress. This is accepted, so nothing else of value is kept
  there.
- Fetching work on the desktop pulls Git objects, not configuration or hooks;
  the owner reviews it before running or merging it.

### Accepted risks

- No impermanence: the server rarely reboots, and the agent account's work in
  progress, where a hijacked agent would leave its code, has to be kept
  anyway.
- A compromised agent account can reach whatever the tailnet lets dracaena
  reach, including services on the desktop. Tailnet access rules are managed
  outside this flake.
- A local privilege escalation (kernel exploit) from the agent account gets
  root on the server, and with it the proxy credentials and the tailnet
  identity.
- Vulnerabilities in the internet-facing services (SSH, the proxy) are
  mitigated only by keeping them updated and key-only.

## Out of scope (accepted, all hosts)

- A compromised package or flake input that the flake installs. (Packages it
  does not install are untrusted; see *Trust line*.)
- Anything already running as root.
- Physical access. USB device allow-listing covers part of it; the desktop's
  Linux root partition is not encrypted.
- Malware already running as the user with persistence.