# vm-run template `agent`: the hosts' coding agents with their config (the
# `agents` Home Manager module), the host's logins, internet, and a working
# `nix` so an agent can fetch any tool it lacks (`nix shell nixpkgs#<pkg>`,
# `nix run`).
{ config, inputs, ... }:
let
  inherit (config.flake.modules) generic homeManager;
in
{
  flake.modules.homeManager.vm-run =
    { pkgs, ... }:
    let
      # Runs on the host before each boot (vm-run.seed); its output lands in
      # the guest user's home.
      seed = pkgs.writeShellApplication {
        name = "vm-run-agent-seed";
        runtimeInputs = with pkgs; [
          coreutils
          jq
          openssl
        ];
        text = ''
          seed=$1

          # The host's logins, copied per run. A refresh inside the guest
          # stays in the guest; a missing file means that agent asks for a
          # login.
          copy_login() {
            if [ -e "$HOME/$1" ]; then
              install -D -m 0600 "$HOME/$1" "$seed/$1"
            else
              echo "vm-run agent: no ~/$1; that agent will ask for a login" >&2
            fi
          }
          copy_login .claude/.credentials.json
          copy_login .codex/auth.json
          copy_login .local/share/opencode/auth.json
          copy_login .local/share/devin/credentials.toml

          # One install id per harness for every agent VM, made on first use
          # and separate from the host's: the harnesses send them with each
          # request (Claude Code userID/machineID, Codex installation_id).
          ids="''${XDG_DATA_HOME:-$HOME/.local/share}/vm-run/agent-ids"
          if [ ! -d "$ids" ]; then
            mkdir -p "$ids.new"
            openssl rand -hex 32 > "$ids.new/claude-user-id"
            openssl rand -hex 32 > "$ids.new/claude-machine-id"
            cat /proc/sys/kernel/random/uuid > "$ids.new/codex-installation-id"
            mv "$ids.new" "$ids"
          fi

          # Claude Code's account record gets only the fields a login needs,
          # so the host's project history and paths stay on the host.
          account=null
          if [ -e "$HOME/.claude.json" ]; then
            account=$(jq '.oauthAccount // null' "$HOME/.claude.json")
          fi
          jq -n \
            --arg user "$(cat "$ids/claude-user-id")" \
            --arg machine "$(cat "$ids/claude-machine-id")" \
            --argjson account "$account" \
            '{ userID: $user, machineID: $machine, hasCompletedOnboarding: true }
              + (if $account == null then {} else { oauthAccount: $account } end)' \
            > "$seed/.claude.json"
          chmod 0600 "$seed/.claude.json"
          install -D -m 0644 "$ids/codex-installation-id" "$seed/.codex/installation_id"
        '';
      };
    in
    {
      programs.vm-run.templates.agent =
        { config, lib, ... }:
        {
          imports = [ inputs.home-manager.nixosModules.home-manager ];

          vm-run = {
            internet = true;
            inherit seed;
          };

          microvm = {
            vcpu = 4;
            mem = 8192;
            # Store paths fetched in the guest go to an overlay on a disk
            # image in the run's directory, which is deleted with the run.
            # Images are sparse (created with truncate), so the size is a
            # ceiling.
            writableStoreOverlay = "/nix/.rw-store";
            volumes = [
              {
                image = "nix-store-overlay.img";
                mountPoint = "/nix/.rw-store";
                size = 40 * 1024;
              }
            ];
          };

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${config.vm-run.user} =
              { config, ... }:
              {
                # generic.base declares options the agent modules set
                # (`persistence`, which has no effect here).
                imports = [
                  generic.base
                  homeManager.agents
                ];
                # Home Manager's own release: it accepts only releases it knows,
                # and on unstable it can lag behind nixpkgs' release.
                home.stateVersion = config.home.version.release;
              };
          };

          nix = {
            enable = true;
            settings = {
              experimental-features = [
                "nix-command"
                "flakes"
              ];
              # Only the local registry below: `nixpkgs` must not resolve to
              # whatever the global registry points at today.
              flake-registry = "";
            };
            # `nix shell nixpkgs#<pkg>` uses the same nixpkgs as the guest, so
            # most fetches are store paths the guest already has or the
            # binary cache serves.
            registry.nixpkgs.to = {
              type = "path";
              inherit (pkgs) path;
            };
            nixPath = [ "nixpkgs=${pkgs.path}" ];
          };
        };
    };
}
