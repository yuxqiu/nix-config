{
  flake.modules.homeManager.base =
    { pkgs, ... }:
    let
      # Runs on the remote host, inside a `nix shell` providing sops,
      # ssh-to-age and neovim: `run.sh <edit|updatekeys> <key> <file>`.
      remoteRun = pkgs.writeText "sops-remote-run.sh" ''
        set -euo pipefail
        cd "$(dirname "$0")"
        mode="$1"
        key_path="$2"
        file="$3"
        ssh_to_age_bin="$(command -v ssh-to-age)"
        if [ -r "$key_path" ]; then
          SOPS_AGE_KEY="$("$ssh_to_age_bin" -private-key -i "$key_path")"
        else
          SOPS_AGE_KEY="$(sudo "$ssh_to_age_bin" -private-key -i "$key_path")"
        fi
        export SOPS_AGE_KEY
        case "$mode" in
          edit) EDITOR="nvim" sops "$file" ;;
          updatekeys) sops updatekeys "$file" ;;
        esac
      '';

      # A key written as `[user@]host:/path` lives on that host. Its private
      # half never leaves it: the encrypted file is copied over, sops runs
      # there, and the result is copied back.
      remoteLib = ''
        # Every ssh/scp below shares one authenticated connection per host, so
        # a confirming agent (ssh-agent-ac) asks once instead of per command.
        ssh_ctl_dir="$(mktemp -d)"
        ssh_opts=(-o ControlMaster=auto -o "ControlPath=$ssh_ctl_dir/%C" -o ControlPersist=yes)
        # Remote arguments are quoted with printf %q, so expanding them on
        # this side before ssh sends them is intended.
        # shellcheck disable=SC2029
        rssh() { ssh "''${ssh_opts[@]}" "$@"; }
        rscp() { scp "''${ssh_opts[@]}" "$@"; }

        # Runs on exit: remote cleanup first (over the shared connection), then
        # close the connections.
        remote_cleanup=""
        cleanup() {
          if [ -n "$remote_cleanup" ]; then eval "$remote_cleanup" || true; fi
          for sock in "$ssh_ctl_dir"/*; do
            [ -S "$sock" ] && ssh -o "ControlPath=$sock" -O exit _ 2>/dev/null || true
          done
          rm -rf "$ssh_ctl_dir"
        }
        trap cleanup EXIT

        is_remote() {
          case "$1" in
            *:*) return 0 ;;
            *) return 1 ;;
          esac
        }

        # Prints the SSH public key of a local or remote private key path.
        read_pub() {
          if is_remote "$1"; then
            rssh -n "''${1%%:*}" cat "$(printf "%q" "''${1#*:}.pub")"
          else
            if [ ! -f "$1.pub" ]; then
              echo "Missing SSH public key: $1.pub" >&2
              return 1
            fi
            cat "$1.pub"
          fi
        }

        # remote_sops <edit|updatekeys> <host:key> <local file> <path on host> [.sops.yaml]
        remote_sops() {
          local mode="$1" spec="$2" local_file="$3" rel="$4" sops_yaml="''${5:-}"
          local host="''${spec%%:*}" key="''${spec#*:}" rdir
          rdir="$(rssh -n "$host" mktemp -d)"
          remote_cleanup="rssh -n $(printf "%q" "$host") rm -rf $(printf "%q" "$rdir")"
          rssh -n "$host" mkdir -p "$(printf "%q" "$rdir/$(dirname "$rel")")"
          rscp -q ${remoteRun} "$host:$rdir/run.sh"
          rscp -q "$local_file" "$host:$rdir/$rel"
          if [ -n "$sops_yaml" ]; then
            rscp -q "$sops_yaml" "$host:$rdir/.sops.yaml"
          fi
          rssh -t "$host" "$(printf "%q " nix shell nixpkgs#sops nixpkgs#ssh-to-age nixpkgs#neovim \
            -c bash "$rdir/run.sh" "$mode" "$key" "$rel")"
          rscp -q "$host:$rdir/$rel" "$local_file"
        }
      '';

      sops-update = pkgs.writeShellApplication {
        name = "sops-update";
        runtimeInputs = with pkgs; [
          coreutils
          openssh
          ssh-to-age
          neovim
          sops
        ];
        text = ''
          set -euo pipefail

          ${remoteLib}

          usage() {
            echo "Usage: sops-update <key> <file>" >&2
            echo "  <key>: a local key path, or [user@]host:/path for a key on that host" >&2
            exit 1
          }

          if [ "$#" -ne 2 ]; then
            usage
          fi

          key_path="$1"
          file="$2"
          ssh_to_age_bin="$(command -v ssh-to-age)"

          if is_remote "$key_path"; then
            remote_sops edit "$key_path" "$file" "$(basename "$file")"
            exit 0
          fi

          if [ -r "$key_path" ]; then
            age_key="$("$ssh_to_age_bin" -private-key -i "$key_path")"
          else
            age_key="$(sudo "$ssh_to_age_bin" -private-key -i "$key_path")"
          fi
          SOPS_AGE_KEY="$age_key" \
            EDITOR="nvim" \
            sops "$file"
        '';
      };

      sops-update-key = pkgs.writeShellApplication {
        name = "sops-update-key";
        runtimeInputs = with pkgs; [
          coreutils
          git
          openssh
          ssh-to-age
          gnugrep
          gawk
          gnused
          sops
        ];
        text = ''
            set -euo pipefail

            ${remoteLib}

            usage() {
              echo "Usage: sops-update-key <mode> <decrypt_key> <key> <file>" >&2
              echo "Keys are local paths, or [user@]host:/path for a key on that host" >&2
              echo "Modes: add, remove" >&2
              echo "  <decrypt_key>: a key you currently hold, used to perform the update" >&2
              echo "  add:    <key> is the new key to add" >&2
              echo "  remove: <key> is the key to remove (may be <decrypt_key> itself)" >&2
              exit 1
            }

            if [ "$#" -ne 4 ]; then
              usage
            fi

            mode="$1"
            decrypt_key_path="$2"
            key_path="$3"
            file="$4"
            ssh_to_age_bin="$(command -v ssh-to-age)"

            case "$mode" in
              add|remove)
                ;;
              *)
                usage
                ;;
            esac

            find_sops_root() {
              if [ -f ".sops.yaml" ]; then
                pwd
                return 0
              fi

              if git rev-parse --show-toplevel >/dev/null 2>&1; then
                root="$(git rev-parse --show-toplevel)"
                if [ -f "$root/nix/.sops.yaml" ]; then
                  echo "$root/nix"
                  return 0
                fi
                if [ -f "$root/.sops.yaml" ]; then
                  echo "$root"
                  return 0
                fi
              fi

              return 1
            }

            sops_root="$(find_sops_root || true)"
            if [ -z "$sops_root" ]; then
              echo "Could not find .sops.yaml" >&2
              exit 1
            fi

            file_abs="$(realpath "$file")"
            file_rel="$(realpath --relative-to="$sops_root" "$file")"

            cd "$sops_root"

            sops_yaml="$sops_root/.sops.yaml"

            target_key_name="$(basename "''${key_path#*:}")"
            target_key_name="$(printf "%s" "$target_key_name" | sed 's/\.pub$//')"

            decrypt_key="$(read_pub "$decrypt_key_path" | "$ssh_to_age_bin")"
            target_key="$(read_pub "$key_path" | "$ssh_to_age_bin")"

            # A remote decrypt key is converted on its own host by remote_sops.
            identity=""
            if is_remote "$decrypt_key_path"; then
              true
            elif [ -r "$decrypt_key_path" ]; then
              identity="$("$ssh_to_age_bin" -private-key -i "$decrypt_key_path")"
            else
              identity="$(sudo "$ssh_to_age_bin" -private-key -i "$decrypt_key_path")"
            fi

            case "$mode" in
              add)
                if ! grep -Fq "$decrypt_key" "$sops_yaml"; then
                  echo "decrypt_key not found in .sops.yaml" >&2
                  exit 1
                fi
                if grep -Fq "$target_key" "$sops_yaml"; then
                  echo "Key already present in .sops.yaml" >&2
                  exit 1
                fi
                ;;
              remove)
                if ! grep -Fq "$target_key" "$sops_yaml"; then
                  echo "Key not found in .sops.yaml" >&2
                  exit 1
                fi
                ;;
            esac

            tmp="$(mktemp)"
            case "$mode" in
              add)
                if ! awk -v old="$decrypt_key" -v new="$target_key" -v new_name="$target_key_name" '
                  {
                    if (old_name == "" && index($0, old)) {
                      if (match($0, /&[^[:space:]]+/)) {
                        old_name = substr($0, RSTART + 1, RLENGTH - 1)
                      }
                  }
                  if (!added_key && index($0, old)) {
                    print
                    line = $0
                    line = gensub(/&[^[:space:]]+/, "\\&" new_name, 1, line)
                    line = gensub(old, new, 1, line)
                    print line
                    added_key = 1
                    next
                  }
                  if (old_name != "" && index($0, "*" old_name)) {
                    print
                    print gensub(/\*[^[:space:]]+/, "*" new_name, 1, $0)
                    added_ref = 1
                    next
                  }
                  print
                }
                END {
                  if (!added_key || !added_ref) {
                    exit 3
                  }
                }
              ' "$sops_yaml" > "$tmp"; then
                  rm -f "$tmp"
                  echo "Failed to add new key to .sops.yaml" >&2
                  exit 1
                fi
                ;;
              remove)
                if ! awk -v old="$target_key" '
                  {
                    if (old_name == "" && index($0, old)) {
                      if (match($0, /&[^[:space:]]+/)) {
                        old_name = substr($0, RSTART + 1, RLENGTH - 1)
                      }
                  }
                  if (index($0, old)) {
                    removed_key = 1
                    next
                  }
                  if (old_name != "" && index($0, "*" old_name)) {
                    removed_ref = 1
                    next
                  }
                  print
                }
                END {
                  if (!removed_key) {
                    exit 3
                  }
                  if (old_name != "" && !removed_ref) {
                    exit 3
                  }
                }
              ' "$sops_yaml" > "$tmp"; then
                  rm -f "$tmp"
                  echo "Failed to remove key from .sops.yaml" >&2
                  exit 1
                fi
                ;;
          esac

          mv "$tmp" "$sops_yaml"

          if is_remote "$decrypt_key_path"; then
            remote_sops updatekeys "$decrypt_key_path" "$file_abs" "$file_rel" "$sops_yaml"
          else
            SOPS_AGE_KEY="$identity" \
              sops updatekeys "$file"
          fi
        '';
      };
    in
    {
      home.packages = [
        sops-update
        sops-update-key
      ];
    };
}
