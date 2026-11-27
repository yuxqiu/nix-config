# os-bootstrap <host>
#
# Prepares the machine it runs on, already running NixOS (e.g. from the
# graphical installer), to switch to this flake's <host>. Run from a checkout
# of the flake, as a user who can sudo. Safe to rerun; each step is skipped
# once done:
#
#   1. Makes the host's age key, where the host's config will read it
#      (`sops.age.keyFile`). On a host with impermanence the key lives on the
#      persistent filesystem, so it goes wherever that filesystem is mounted
#      now: at `/` on a machine converted in place (its root becomes the
#      persistent filesystem), at `persistence.storage` on one already laid
#      out or switched, or at any other mount point. Stops if it is not
#      mounted.
#   2. Grants that key access to the host's secrets (sops-update-key).
#   3. Copies the installer's hardware configuration into the host directory.
#   4. Lists secrets the host needs before users exist (password hashes) that
#      the secrets file lacks, with the commands to add them.
#
# When nothing is missing it prints the command that installs the host.
{
  writeShellApplication,
  age,
  coreutils,
  gawk,
  git,
  gnugrep,
  sops-tools,
  util-linux,
  yq-go,
}:
writeShellApplication {
  name = "os-bootstrap";
  runtimeInputs = [
    age
    coreutils
    gawk
    git
    gnugrep
    sops-tools
    util-linux
    yq-go
  ];
  text = ''
    if [ $# -ne 1 ] || [[ "$1" == -* ]]; then
      echo "Usage: os-bootstrap <host>" >&2
      exit 1
    fi
    host="$1"
    dir="profiles/hosts/$host"
    secrets="$dir/secrets/$host.yaml"
    hardware="$dir/_hardware-configuration.nix"

    die() { echo "os-bootstrap: $*" >&2; exit 1; }
    [ -d "$dir" ] || die "no $dir; run from the flake root after creating the host"
    [ -f .sops.yaml ] || die "no .sops.yaml; run from the flake root"
    [ -f "$secrets" ] || die "no $secrets; create it with: sops-update admin $secrets"

    # `nix` and `sudo` come from PATH: the running system's.
    eval_host() {
      nix --extra-experimental-features 'nix-command flakes' eval "$@" ".#nixosConfigurations.$host.config" ||
        die "could not evaluate $host (error above)"
    }
    key_file="$(eval_host --raw --apply 'c: c.sops.age.keyFile')"
    storage="$(eval_host --raw --apply 'c: c.persistence.storage or ""')"
    user_secrets="$(eval_host --raw --apply 'c: builtins.concatStringsSep "\n" (builtins.filter (n: (builtins.getAttr n c.sops.secrets).neededForUsers) (builtins.attrNames c.sops.secrets))')"

    # 1. The key, on the filesystem that will hold it once the host's config
    # is running.
    key="$key_file"
    if [ -n "$storage" ]; then
      case "$key_file" in
        "$storage"/*) ;;
        *) die "sops.age.keyFile ($key_file) is not on persistence.storage ($storage)" ;;
      esac
      # The filesystem the config mounts at $storage: its device, and for a
      # btrfs subvolume the subvolume, which findmnt reports as FSROOT (bind
      # mounts of its directories have other FSROOTs).
      device="$(nix --extra-experimental-features 'nix-command flakes' eval --raw ".#nixosConfigurations.$host.config.fileSystems" --apply "fs: (builtins.getAttr \"$storage\" fs).device")" ||
        die "the config has no fileSystems.\"$storage\" (error above)"
      options="$(nix --extra-experimental-features 'nix-command flakes' eval --raw ".#nixosConfigurations.$host.config.fileSystems" --apply "fs: builtins.concatStringsSep \",\" (builtins.getAttr \"$storage\" fs).options")"
      fs_root=/
      IFS=, read -ra opts <<<"$options"
      for opt in "''${opts[@]}"; do
        case "$opt" in
          subvol=*)
            # findmnt reports a subvolume as /<path> and the top level as /;
            # the option may spell either with any number of leading slashes.
            fs_root="''${opt#subvol=}"
            while [[ $fs_root == /* ]]; do fs_root="''${fs_root#/}"; done
            fs_root="/$fs_root"
            ;;
          subvolid=*) die "fileSystems.\"$storage\" selects its subvolume by subvolid; use subvol=<name>" ;;
        esac
      done
      mapfile -t mounted_at < <(findmnt -rn -o TARGET,FSROOT --source "$device" | awk -v root="$fs_root" '$2 == root { print $1 }')
      case "''${#mounted_at[@]}" in
        0) die "the persistent filesystem ($device, $fs_root) is not mounted; open its encryption and mount it, then rerun" ;;
        1) ;;
        *) die "the persistent filesystem ($device, $fs_root) is mounted at several places: ''${mounted_at[*]}" ;;
      esac
      base="''${mounted_at[0]%/}"
      key="$base''${key_file#"$storage"}"
      echo "Impermanent host: its persistent filesystem is mounted at ''${mounted_at[0]}, so the key goes at $key."
    fi
    if sudo test -e "$key"; then
      if ! sudo test -e "$key.pub"; then
        sudo sh -c "$(command -v age-keygen) -y '$key' > '$key.pub' && chmod 644 '$key.pub'"
      fi
      echo "1. Host key exists: $key"
    else
      sudo install -d -m 755 "$(dirname "$key")"
      sudo sh -c "umask 077 && $(command -v age-keygen) -pq -o '$key'" 2>/dev/null
      sudo sh -c "$(command -v age-keygen) -y '$key' > '$key.pub' && chmod 644 '$key.pub'"
      echo "1. Made the host key: $key"
    fi

    # 2. Access to the secrets file.
    recipient="$(cat "$key.pub")"
    if grep -Fq "$recipient" .sops.yaml; then
      echo "2. The key already has access to $secrets"
    else
      sops-update-key add admin "$key" "$secrets"
      echo "2. Granted the key access to $secrets"
    fi

    # 3. Hardware configuration.
    if [ -e "$hardware" ]; then
      echo "3. $hardware exists"
    else
      [ -f /etc/nixos/hardware-configuration.nix ] ||
        die "no /etc/nixos/hardware-configuration.nix; generate it with: sudo nixos-generate-config"
      cp /etc/nixos/hardware-configuration.nix "$hardware"
      git add "$hardware"
      echo "3. Copied the hardware configuration to $hardware"
    fi

    # 4. Secrets needed before users exist.
    missing=()
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      export NAME="$name"
      if [ "$(yq 'has(strenv(NAME))' "$secrets")" != true ]; then missing+=("$name"); fi
    done <<<"$user_secrets"
    if [ "''${#missing[@]}" -gt 0 ]; then
      echo
      echo "4. $secrets lacks secrets the host needs before users exist:"
      printf '     %s\n' "''${missing[@]}"
      echo "   For a password: run 'mkpasswd -m yescrypt', then 'sops-update admin $secrets'"
      echo "   and add '<name>: <hash>'. Then run os-bootstrap $host again."
      exit 1
    fi
    echo "4. All secrets needed before users exist are present"

    echo
    echo "Ready. Commit .sops.yaml, $secrets and $hardware, then install and reboot:"
    echo "  sudo nixos-rebuild boot --flake .#$host --extra-experimental-features 'nix-command flakes'"
  '';
}
