# dracaena

Headless cloud server, aarch64, provisioned declaratively with
[disko](https://github.com/nix-community/disko) +
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
(`os-install dracaena root@<ip>`). Host files: `profiles/hosts/dracaena/`.

- Account `snowflake` runs coding agents: key-only SSH, no sudo, no Git
  hosting credentials. Work leaves the server only by the desktop fetching it
  over the tailnet.
- Root logs in over SSH with the owner's key; deploy with
  `os-switch dracaena root@<host>` (built on the server).
- No impermanence: the root persists. Why is recorded in the threat model.
