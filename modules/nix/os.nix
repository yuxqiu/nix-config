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
          inputs.nix-update-git.packages.${pkgs.stdenv.system}.default
        ];
        text = ''
          flake-edit follow
          nix-update-git -u . --rules all
          nix flake update
        '';
      };

      os-switch = pkgs.writeShellApplication {
        name = "os-switch";
        runtimeInputs = [ pkgs.nh ];
        text = ''
          if [ $# -eq 0 ] || [[ "$1" == -* ]]; then
            echo "Usage: os-switch <flake-output-name> [user@host] [nh os switch flags...]"
            echo "Example: os-switch cedrus"
            echo "Example: os-switch cedrus --ask -- --show-trace"
            echo "Example: os-switch dracaena root@<ip>"
            exit 1
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
            # Logging in as root needs no sudo on the target.
            elevation=auto
            [[ "$target" == root@* ]] && elevation=none
            nh os switch . -H "$host" --build-host "$target" --target-host "$target" -e "$elevation" "$@"
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
        (pkgs.callPackage (inputs.self + /packages/os-install.nix) {
          sops-tools = pkgs.callPackage (inputs.self + /packages/sops-tools.nix) { };
        })
        hm-news
      ];
    };

  # For a machine that runs NixOS but not yet this flake (e.g. fresh from the
  # graphical installer): `nix --extra-experimental-features 'nix-command
  # flakes' develop .#bootstrap` from a checkout.
  perSystem =
    { pkgs, ... }:
    let
      sops-tools = pkgs.callPackage (inputs.self + /packages/sops-tools.nix) { };
      os-bootstrap = pkgs.callPackage (inputs.self + /packages/os-bootstrap.nix) { inherit sops-tools; };
    in
    {
      devShells.bootstrap = pkgs.mkShell {
        packages = [
          os-bootstrap
          sops-tools
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
