{ inputs, ... }:
{
  flake.modules.homeManager.os =
    { config, pkgs, ... }:
    let
      # Run from the flake root. `nix` is deliberately taken from PATH, not
      # runtimeInputs, so these use the system's Nix (matching the daemon and
      # `nix.package`) like nh does internally.
      os-update = pkgs.writeShellApplication {
        name = "os-update";
        runtimeInputs = [
          pkgs.flake-edit
          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nix-update-git
        ];
        text = ''
          flake-edit follow
          nix-update-git -u . --rules all
          nix flake update
        '';
      };

      os-switch = pkgs.writeShellApplication {
        name = "os-switch";
        # The command run on the target over ssh is built here on purpose,
        # with every value quoted by `printf %q`.
        excludeShellChecks = [ "SC2029" ];
        runtimeInputs = [
          pkgs.jq
          pkgs.nh
          pkgs.openssh
        ];
        text = ''
          usage() {
            echo "Usage: os-switch <flake-output-name> [user@host [--build-on local|remote]] [nh os switch flags...]"
            echo "Example: os-switch cedrus"
            echo "Example: os-switch cedrus --ask -- --show-trace"
            echo "Example: os-switch dracaena root@<ip>"
            echo "Example: os-switch dracaena root@<ip> --build-on remote"
            exit 1
          }
          if [ $# -eq 0 ] || [[ "$1" == -* ]]; then
            usage
          fi
          host="$1"
          shift
          # A second argument not starting with "-" is the remote target;
          # everything after it goes to `nh os switch` unchanged.
          if [ $# -eq 0 ] || [[ "$1" == -* ]]; then
            nh os switch . -H "$host" "$@"
            # From PATH, not runtimeInputs: the profile now points at the new
            # generation, whose hm-news carries the new news.
            hm-news --notify
          else
            target="$1"
            shift
            # By default this host evaluates and the target builds (nh
            # --build-host). That fails if evaluation needs a package built
            # that no trusted cache has signed: Nix builds it on the target and
            # this host refuses the unsigned copy. --build-on overrides it:
            # - remote: upload the flake and every locked input (so the target
            #   never fetches, private inputs included) and run nh on the
            #   target, taken from the flake's own nixpkgs so the target needs
            #   no nh of its own; the target evaluates and builds.
            # - local: evaluate and build here; nh copies the closure over.
            build_on=""
            if [ "''${1:-}" = --build-on ]; then
              [ $# -ge 2 ] || usage
              build_on="$2"
              shift 2
            fi
            # Logging in as root needs no sudo on the target.
            elevation=auto
            [[ "$target" == root@* ]] && elevation=none
            case "$build_on" in
              "")
                nh os switch . -H "$host" --build-host "$target" --target-host "$target" -e "$elevation" "$@"
                ;;
              remote)
                archive="$(nix flake archive --json --no-check-sigs --to "ssh-ng://$target" .)"
                flake="$(jq -r .path <<<"$archive")"
                nixpkgs="$(jq -r .inputs.nixpkgs.path <<<"$archive")"
                ssh -t "$target" "$(printf '%q ' nix run "path:$nixpkgs#nh" -- \
                  os switch "path:$flake" -H "$host" -e "$elevation" "$@")"
                ;;
              local)
                nh os switch . -H "$host" --target-host "$target" -e "$elevation" "$@"
                ;;
              *) echo "--build-on takes local or remote, not $build_on" >&2; exit 1 ;;
            esac
          fi
        '';
      };

      # Home Manager's own `news` command only works for standalone installs.
      # This reads the news of the generation it was built with and shares
      # Home Manager's read-state file, mirroring `home-manager news`.
      hm-news = pkgs.writeShellApplication {
        name = "hm-news";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
          pkgs.less
        ];
        text = ''
          news="${config.news.json.output}"
          data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/home-manager"
          read_ids="$data_dir/news-read-ids"

          mkdir -p "$data_dir"
          touch "$read_ids"

          # Relevant entries, newest first, each flagged with whether it was read.
          entries() {
            jq --rawfile ids "$read_ids" '
              ($ids | split("\n") | map(select(length > 0) | {(.): true}) | add // {}) as $read
              | [.entries[] | select(.condition)]
              | sort_by(.time) | reverse
              | map(. + {read: ($read[.id] // false)})
            ' "$news"
          }

          case "''${1:-}" in
            "")
              rendered_news="$(mktemp)"
              trap 'rm -f "$rendered_news"' EXIT
              entries | jq -r '.[]
                | "* \(.time | sub("T"; " ") | sub("\\+00:00$"; "")) [\(if .read then "read" else "unread" end)]\n\n  \(.message | gsub("\n"; "\n  "))\n"' > "$rendered_news"
              # shellcheck disable=SC2086
              ''${PAGER:-less -R} < "$rendered_news"
              { cat "$read_ids"; jq -r '.entries[].id' "$news"; } | sort -u > "$read_ids.new"
              mv -f "$read_ids.new" "$read_ids"
              ;;
            --notify)
              [ "$(jq -r .display "$news")" = silent ] && exit 0
              unread="$(entries | jq 'map(select(.read | not)) | length')"
              if [ "$unread" -eq 1 ]; then
                echo "There is 1 unread and relevant Home Manager news item. Read it by running \"hm-news\"."
              elif [ "$unread" -gt 1 ]; then
                echo "There are $unread unread and relevant Home Manager news items. Read them by running \"hm-news\"."
              fi
              ;;
            *)
              echo "Usage: hm-news [--notify]" >&2
              exit 1
              ;;
          esac
        '';
      };
    in
    {
      # hm-news's read state. Kept as a directory: it saves by renaming a new
      # file over news-read-ids, which a kept single file cannot take.
      persistence.directories = [ ".local/share/home-manager" ];
      home.packages = [
        os-update
        os-switch
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.os-install
        hm-news
      ];
    };

  # For a machine that runs NixOS but not yet this flake (e.g. fresh from the
  # graphical installer): `nix --extra-experimental-features 'nix-command
  # flakes' develop .#bootstrap` from a checkout.
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.bootstrap = pkgs.mkShell {
        packages = [
          self'.packages.os-bootstrap
          self'.packages.sops-tools
          pkgs.mkpasswd
          pkgs.git
        ];
        shellHook = ''
          cat <<'EOF'
          Bringing this machine into the flake as <host>:
            1. Create profiles/hosts/<host>/ (start from cedrus or dracaena), add the
               host to globals/tailnet.nix, add a .sops.yaml rule for
               profiles/hosts/<host>/secrets/<host>.yaml with only the admin key,
               create it with `sops-update admin <file>`, and `git add` it all.
            2. os-bootstrap <host>
               Makes the host key, grants it, copies the hardware configuration,
               and lists secrets still missing (e.g. password hashes:
               `mkpasswd -m yescrypt`, then `sops-update admin <file>`).
               Rerun until it says Ready.
            3. Run the command it prints (nixos-rebuild boot), then reboot.
          EOF
        '';
      };
    };
}
