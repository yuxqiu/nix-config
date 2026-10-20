### Nix Workflow

This repo's root is the flake root. Always work from here.

Available hosts (under `profiles/hosts/`):
```
ls profiles/hosts/
```
If the user does not specify a host, ask which one they want to change.

**Build check** (fast, no side effects):

Hosts are declared under `configurations.nixos` or `configurations.homeManager` in `profiles/hosts/<host>.nix`. Pick the matching build command:

```
# NixOS host
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link --print-out-paths 2>/dev/null

# home-manager only host
nix build .#homeConfigurations.<host>.activationPackage --no-link --print-out-paths 2>/dev/null
```

**Key conventions**:
- Module files go under `modules/` and are auto-discovered by `import-tree`.
- Each file declares `flake.modules.homeManager.<name>` (or `systemManager`, `generic`).
- Host config at `profiles/hosts/<host>.nix` lists which modules to include.
- `pkgs` is available inside the inner `flake.modules.*` function, not the outer one — the outer function receives `{ inputs, ... }`.
- Prefer `fetchFromGitHub` over flake inputs for non-Nix repos (no `flake.nix`). Prefer stable release tags when available, using the package's `version` in the fetch (e.g. `rev = "v${version}";` inside `mkDerivation rec { ... }`, as in `packages/codeburn.nix`) so `nix-update-git` updates the version and source hash together. Check new fetches with `nix-update-git --check <file>`.
- Use branch tracking only when stable releases are unavailable or explicitly requested. In that case, use a standalone `let` fetch with a pinned `rev`, `hash`, and `# follow:branch <branch>`, then `inherit src;` in the derivation (e.g. `packages/unicode-highlight-nvim.nix`). The current updater's derivation rule ignores branch-follow directives on inline `src` fetches.
- After editing nix files, if there are newly added files, `git add` them before building — the flake evaluates the git-tracked tree.
- Do NOT apply changes (no `home-manager switch`, no `hm`). Build-check only; the user will apply themselves.
- When modifying configs that have runtime behavior (e.g. nvim, neovim, shell configs, services), try your best to test different workflows after building to ensure the modification is correct — not just that it builds.
