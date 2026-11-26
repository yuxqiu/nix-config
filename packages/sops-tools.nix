# sops-update and sops-update-key: edit sops files and change who can read
# them, using only post-quantum age keys (age-keygen -pq).
#
# A key argument is one of:
#   admin                the admin key, read from Proton Pass when needed
#   /path/key.txt        an age identity file on this machine (sudo if needed)
#   [user@]host:/path    an age identity file on that host; it never leaves it
#
# Using the admin key logs in to Proton Pass in a private session for this
# run (its own session directory and key, no keyring needed) and always logs
# out when the command exits, so no session is left behind.
{
  lib,
  writeShellApplication,
  symlinkJoin,
  writeText,
  age,
  coreutils,
  git,
  neovim,
  openssh,
  proton-pass-cli,
  sops,
  yq-go,
}:
let
  # Proton Pass item holding the admin identity (AGE-SECRET-KEY-PQ-1...): a
  # custom item whose `key` field is hidden, so the apps mask it.
  adminItem = [
    "--vault-name"
    "sops"
    "--item-title"
    "age-admin"
    "--field"
    "key"
  ];
  adminKeyCmd = lib.escapeShellArgs (
    [
      "pass-cli"
      "item"
      "view"
    ]
    ++ adminItem
  );

  # Runs on the remote host: `run.sh <edit|reencrypt> <key> <file>`. The host
  # has sops from the sops NixOS module; nvim comes from nixpkgs for editing.
  remoteRun = writeText "sops-remote-run.sh" ''
    set -euo pipefail
    cd "$(dirname "$0")"
    mode="$1"
    key_path="$2"
    file="$3"
    unset SOPS_AGE_KEY SOPS_AGE_KEY_FILE SOPS_AGE_KEY_CMD
    if [ -r "$key_path" ]; then
      export SOPS_AGE_KEY_FILE="$key_path"
    else
      export SOPS_AGE_KEY_CMD="sudo cat $key_path"
    fi
    case "$mode" in
      edit) nix shell nixpkgs#neovim -c env EDITOR=nvim sops "$file" ;;
      reencrypt) sops rotate -i "$file" && sops updatekeys -y "$file" ;;
    esac
  '';

  lib-sh = ''
    # Every ssh/scp below shares one authenticated connection per host, so
    # a confirming agent (ssh-agent-ac) asks once instead of per command.
    ssh_ctl_dir="$(mktemp -d)"
    ssh_opts=(-o ControlMaster=auto -o "ControlPath=$ssh_ctl_dir/%C" -o ControlPersist=yes)
    # Remote arguments are quoted with printf %q, so expanding them on
    # this side before ssh sends them is intended.
    # shellcheck disable=SC2029
    rssh() { ssh "''${ssh_opts[@]}" "$@"; }
    rscp() { scp "''${ssh_opts[@]}" "$@"; }

    remote_cleanup=""
    pass_used=""
    cleanup() {
      if [ -n "$remote_cleanup" ]; then eval "$remote_cleanup" || true; fi
      for sock in "$ssh_ctl_dir"/*; do
        [ -S "$sock" ] && ssh -o "ControlPath=$sock" -O exit _ 2>/dev/null || true
      done
      rm -rf "$ssh_ctl_dir"
      if [ -n "$pass_used" ]; then pass-cli logout >/dev/null; fi
      rm -rf "$pass_dir"
    }
    trap cleanup EXIT

    die() { echo "$*" >&2; exit 1; }

    # A private Proton Pass session per run: a fresh session directory on a
    # tmpfs and a random key that exists only in this process's environment
    # (key provider "env"), so pass-cli needs no keyring, which a fresh
    # install may not have, and a session left by a failed logout can't be
    # decrypted. Each run logs in anyway (pass_session_for).
    pass_dir="$(mktemp -d -p /dev/shm sops-pass.XXXXXXXX)"
    export PROTON_PASS_SESSION_DIR="$pass_dir"
    export PROTON_PASS_KEY_PROVIDER=env
    PROTON_PASS_ENCRYPTION_KEY="$(head -c 32 /dev/urandom | sha256sum | cut -d' ' -f1)"
    export PROTON_PASS_ENCRYPTION_KEY

    is_remote() {
      case "$1" in
        *:*) return 0 ;;
        *) return 1 ;;
      esac
    }

    # Logs in to Proton Pass when any argument is the admin key. Runs in the
    # main shell, not a $(...) subshell, so the exit trap sees pass_used.
    pass_session_for() {
      for arg in "$@"; do
        if [ "$arg" = admin ]; then
          pass_used=1
          if ! pass-cli info >/dev/null 2>&1; then
            pass-cli login
          fi
          return
        fi
      done
    }

    # Points sops at the identity of a local key (admin or a path). The
    # admin key is streamed from Proton Pass by sops itself, so it never
    # touches the disk or an environment variable.
    use_identity() {
      unset SOPS_AGE_KEY SOPS_AGE_KEY_FILE SOPS_AGE_KEY_CMD
      case "$1" in
        admin)
          export SOPS_AGE_KEY_CMD=${lib.escapeShellArg adminKeyCmd}
          ;;
        *)
          if [ -r "$1" ]; then
            export SOPS_AGE_KEY_FILE="$1"
          else
            export SOPS_AGE_KEY_CMD="sudo cat $1"
          fi
          ;;
      esac
    }

    # Prints the age recipient (public key) of a key argument. Host keys
    # have a world-readable `<key>.pub` next to them (written by the sops
    # NixOS module), so reading one needs no root and no age on the host.
    recipient_of() {
      local recipient
      case "$1" in
        admin)
          recipient="$(${adminKeyCmd} | age-keygen -y)"
          ;;
        *:*)
          recipient="$(rssh -n "''${1%%:*}" cat "$(printf "%q" "''${1#*:}.pub")")"
          ;;
        *)
          if [ -f "$1.pub" ]; then
            recipient="$(cat "$1.pub")"
          elif [ -r "$1" ]; then
            recipient="$(age-keygen -y "$1")"
          else
            recipient="$(sudo "$(command -v age-keygen)" -y "$1")"
          fi
          ;;
      esac
      require_pq "$recipient" "$1"
      printf "%s\n" "$recipient"
    }

    # A file is only as strong as its weakest recipient, and sops does not
    # apply age's rule against mixing post-quantum and classic recipients,
    # so every recipient must be post-quantum.
    require_pq() {
      case "$1" in
        age1pq1*) ;;
        *) die "Not a post-quantum age key (age1pq1...): ''${2}" ;;
      esac
    }

    # Directory holding .sops.yaml: the current one, else the git root.
    find_sops_root() {
      if [ -f .sops.yaml ]; then
        pwd
      elif root="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -f "$root/.sops.yaml" ]; then
        echo "$root"
      else
        die "Could not find .sops.yaml"
      fi
    }

    # remote_sops <edit|reencrypt> <host:key> <local file> <path rel. to .sops.yaml> <.sops.yaml>
    remote_sops() {
      local mode="$1" spec="$2" local_file="$3" rel="$4" sops_yaml="$5"
      local host="''${spec%%:*}" key="''${spec#*:}" rdir
      rdir="$(rssh -n "$host" mktemp -d)"
      remote_cleanup="rssh -n $(printf "%q" "$host") rm -rf $(printf "%q" "$rdir")"
      rssh -n "$host" mkdir -p "$(printf "%q" "$rdir/$(dirname "$rel")")"
      rscp -q ${remoteRun} "$host:$rdir/run.sh"
      rscp -q "$local_file" "$host:$rdir/$rel"
      rscp -q "$sops_yaml" "$host:$rdir/.sops.yaml"
      rssh -t "$host" "$(printf "%q " bash "$rdir/run.sh" "$mode" "$key" "$rel")"
      rscp -q "$host:$rdir/$rel" "$local_file"
    }
  '';

  runtimeInputs = [
    age
    coreutils
    git
    openssh
    proton-pass-cli
    sops
    yq-go
  ];

  sops-update = writeShellApplication {
    name = "sops-update";
    runtimeInputs = runtimeInputs ++ [ neovim ];
    text = ''
      ${lib-sh}

      if [ "$#" -ne 2 ]; then
        echo "Usage: sops-update <key> <file>" >&2
        echo "  <key>: admin, a local key path, or [user@]host:/path" >&2
        exit 1
      fi
      key="$1"
      file="$2"
      pass_session_for "$key"

      sops_root="$(find_sops_root)"
      if is_remote "$key"; then
        remote_sops edit "$key" "$(realpath "$file")" \
          "$(realpath --relative-to="$sops_root" "$file")" "$sops_root/.sops.yaml"
      else
        use_identity "$key"
        EDITOR=nvim sops "$file"
      fi
    '';
  };

  sops-update-key = writeShellApplication {
    name = "sops-update-key";
    inherit runtimeInputs;
    text = ''
      ${lib-sh}

      usage() {
        echo "Usage: sops-update-key <add|remove> <decrypt_key> <key> <file>" >&2
        echo "Keys are admin, a local key path, or [user@]host:/path" >&2
        echo "  <decrypt_key>: a key that can read <file> now" >&2
        echo "  add:    give <key> access to <file>" >&2
        echo "  remove: take access from <key> (may be <decrypt_key> itself)" >&2
        echo "Only the .sops.yaml rule matching <file> changes; <file> gets a new data key." >&2
        exit 1
      }

      [ "$#" -eq 4 ] || usage
      mode="$1"
      decrypt_key="$2"
      key="$3"
      file="$4"
      case "$mode" in add | remove) ;; *) usage ;; esac
      [ -f "$file" ] || die "No such file: $file"
      pass_session_for "$decrypt_key" "$key"

      sops_root="$(find_sops_root)"
      sops_yaml="$sops_root/.sops.yaml"
      file_abs="$(realpath "$file")"
      file_rel="$(realpath --relative-to="$sops_root" "$file")"

      # The one creation rule sops uses for this file.
      rule=""
      i=0
      while IFS= read -r regex; do
        if [[ "$file_rel" =~ $regex ]]; then
          [ -z "$rule" ] || die "More than one .sops.yaml rule matches $file_rel"
          rule="$i"
        fi
        i=$((i + 1))
      done < <(yq '.creation_rules[].path_regex' "$sops_yaml")
      [ -n "$rule" ] || die "No .sops.yaml rule matches $file_rel"
      export I="$rule"
      [ "$(yq '.creation_rules[env(I)].key_groups | length' "$sops_yaml")" = 1 ] ||
        die "Rule for $file_rel must have exactly one key group"

      # Read once into a variable: piping yq into `grep -q` under pipefail
      # fails whenever grep exits before yq finishes writing.
      recipients="$(yq 'explode(.) | .creation_rules[env(I)].key_groups[0].age[]' "$sops_yaml")"
      while IFS= read -r r; do require_pq "$r" "a key in the rule for $file_rel"; done <<<"$recipients"

      V="$(recipient_of "$key")"
      export V
      # Anchor already naming this key in `keys:`, if any.
      N="$(yq '.keys[] | select(. == strenv(V)) | anchor' "$sops_yaml")"
      export N

      original="$(cat "$sops_yaml")"
      case "$mode" in
        add)
          if grep -Fxq "$V" <<<"$recipients"; then
            die "Key already in the rule for $file_rel"
          fi
          if [ -z "$N" ]; then
            # A new key is named after the file it was added for (cedrus.yaml
            # gives &cedrus), matching the host keys.
            N="$(basename "$file_rel")"
            N="''${N%.*}"
            if [ "$(yq '[.keys[] | select(anchor == strenv(N))] | length' "$sops_yaml")" != 0 ]; then
              die "Another key is already named &$N in .sops.yaml"
            fi
            yq -i '.keys += [strenv(V)] | .keys[-1] anchor = strenv(N)' "$sops_yaml"
          fi
          yq -i '.creation_rules[env(I)].key_groups[0].age += ["_"]
            | .creation_rules[env(I)].key_groups[0].age[-1] alias = strenv(N)' "$sops_yaml"
          ;;
        remove)
          if ! grep -Fxq "$V" <<<"$recipients"; then
            die "Key not in the rule for $file_rel"
          fi
          [ "$(wc -l <<<"$recipients")" -gt 1 ] || die "Refusing to remove the last key of $file_rel"
          yq -i 'del(.creation_rules[env(I)].key_groups[0].age[] | select(alias == strenv(N)))' "$sops_yaml"
          if [ "$(yq '[.creation_rules[].key_groups[].age[] | select(alias == strenv(N))] | length' "$sops_yaml")" = 0 ]; then
            yq -i 'del(.keys[] | select(anchor == strenv(N)))' "$sops_yaml"
          fi
          ;;
      esac

      # Rotate first: it needs a key that can read the file now, which a
      # removed decrypt key no longer is after updatekeys. updatekeys then
      # wraps the new data key for the rule's keys only.
      if ! if is_remote "$decrypt_key"; then
        remote_sops reencrypt "$decrypt_key" "$file_abs" "$file_rel" "$sops_yaml"
      else
        use_identity "$decrypt_key"
        (cd "$sops_root" && sops rotate -i "$file_rel" && sops updatekeys -y "$file_rel")
      fi; then
        printf "%s\n" "$original" > "$sops_yaml"
        die "Re-encrypting $file_rel failed; .sops.yaml restored"
      fi
      echo "$mode: done; review and commit .sops.yaml and $file_rel" >&2
    '';
  };
in
symlinkJoin {
  name = "sops-tools";
  paths = [
    sops-update
    sops-update-key
  ];
}
