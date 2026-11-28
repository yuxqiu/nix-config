### Nix Workflow

This repo's root is the flake root. Always work from here.

Available hosts (under `profiles/hosts/`):
```
ls profiles/hosts/
```
If the user does not specify a host, ask which one they want to change.

**Build check** (fast, no side effects):

Hosts are declared under `configurations.nixos` in `profiles/hosts/<host>/default.nix`:

```
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link --print-out-paths 2>/dev/null
```

**Key conventions**:
- Module files go under `modules/` and are auto-discovered by `import-tree`.
- `globals/` holds flake-wide facts (`identity`, `tailnet`): each file declares a top-level option on `generic.base` and sets it, so every config reads `config.identity` / `config.tailnet` without importing anything. Keep it to facts about the owner and the machines.
- Each file declares `flake.modules.homeManager.<name>` (or `systemManager`, `generic`).
- Host config at `profiles/hosts/<host>/default.nix` lists which modules to include; the other files in that directory add to `flake.modules.nixos.<host>` / `flake.modules.homeManager.<host>`, one file per module or service they configure (e.g. `backup.nix`, `xremap.nix`).
- A module's kept state (`persistence.directories` / `persistence.files`) comes first in its config, right after `imports`, so what survives a reboot is visible at a glance. Exception: a host's `persistence.nix` sets up the storage itself (its mount, `persistence.storage`, the key path) and lists host-only kept paths after that.
- Including a module turns it on: modules have no `enable` switch (exception: a module replacing an upstream one keeps its option shape, e.g. `services.tailscale.serve`).
- Host-specific values live in the host directory, set through options the module exposes (e.g. `profiles/hosts/cedrus/latex.nix` sets `dev.latex.engine`). An option the host must set has no default, so forgetting it fails at evaluation.
- Options for a tool Home Manager doesn't cover yet go under `programs.<tool>`, so a future upstream module with the same option fails evaluation and gets noticed.
- A user profile (`profiles/users/`) defines the account and grants only `wheel`. Other groups are granted per host in their own file, with a comment on the risk accepted (e.g. `profiles/hosts/cedrus/usbguard.nix`).
- Package builds go in `packages/<name>.nix` (`callPackage` style), never inline in a module or host file. `flake/packages.nix` builds each one once as flake package `<name>`, in one scope so a package can take another as an argument; modules use `inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.<name>`.
- `pkgs` is available inside the inner `flake.modules.*` function, not the outer one — the outer function receives `{ inputs, ... }`.
- Prefer `fetchFromGitHub` over flake inputs for non-Nix repos (no `flake.nix`). Prefer stable release tags when available, using the package's `version` in the fetch (e.g. `rev = "v${version}";` inside `mkDerivation rec { ... }`, as in `packages/codeburn.nix`) so `nix-update-git` updates the version and source hash together. Check new fetches with `nix-update-git --check <file>`.
- Use branch tracking only when stable releases are unavailable or explicitly requested. In that case, use a standalone `let` fetch with a pinned `rev`, `hash`, and `# follow:branch <branch>`, then `inherit src;` in the derivation (e.g. `packages/unicode-highlight-nvim.nix`). The current updater's derivation rule ignores branch-follow directives on inline `src` fetches.
- After editing nix files, if there are newly added files, `git add` them before building — the flake evaluates the git-tracked tree.
- Guard every temporary change with an eval-time `warnings` entry that fires once the reason for it goes away. This covers version pins (a package taken from an older nixpkgs through the `mv` module argument, `mv.versions.<pkg>`), workarounds and vendored copies to revert, and features held back until upstream supports them (e.g. the Firefox 161 check in `modules/desktop/browser/firefox/firefox.nix`). Prefix the message with the file name and say what to change or remove, including the warning itself.
- Do NOT apply changes (no `home-manager switch`, no `hm`). Build-check only; the user will apply themselves.
- When modifying configs that have runtime behavior (e.g. nvim, neovim, shell configs, services), try your best to test different workflows after building to ensure the modification is correct — not just that it builds.
