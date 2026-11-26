# os-install <host> <[user@]address> [nixos-anywhere flags...]
#
# Installs this flake's NixOS host on a remote machine with nixos-anywhere,
# which wipes it. Run from the flake root. The host's age key is made here
# first, in a private directory on a tmpfs (/dev/shm), granted access to the
# host's secrets, and copied onto the new system with --extra-files at the
# host's `sops.age.keyFile`; so the host decrypts its secrets on first boot.
# The local copy is gone when the command exits. A reinstall replaces the
# host's previous key. If the install fails, .sops.yaml and the secrets file
# are restored.
{
  writeShellApplication,
  age,
  coreutils,
  nixos-anywhere,
  openssh,
  sops-tools,
  yq-go,
}:
writeShellApplication {
  name = "os-install";
  runtimeInputs = [
    age
    coreutils
    nixos-anywhere
    openssh
    sops-tools
    yq-go
  ];
  text = ''
    if [ $# -lt 2 ] || [[ "$1" == -* ]] || [[ "$2" == -* ]]; then
      echo "Usage: os-install <host> <[user@]address> [nixos-anywhere flags...]" >&2
      echo "Example: os-install dracaena root@<ip>" >&2
      exit 1
    fi
    host="$1"
    target="$2"
    shift 2

    dir="profiles/hosts/$host"
    secrets="$dir/secrets/$host.yaml"
    # import-tree skips paths containing "/_", so the raw NixOS module that
    # nixos-generate-config writes doesn't break the flake;
    # profiles/configs/nixos.nix imports it into the host.
    hardware="$dir/_hardware-configuration.nix"

    # Checked before nixos-anywhere wipes the target, not after.
    [ -d "$dir" ] || { echo "No $dir; run from the flake root" >&2; exit 1; }
    [ -f "$secrets" ] || { echo "No $secrets; create it encrypted to the admin key first" >&2; exit 1; }
    [ -f .sops.yaml ] || { echo "No .sops.yaml; run from the flake root" >&2; exit 1; }

    # `nix` comes from PATH: the system's Nix, matching the daemon.
    key_file="$(nix eval --raw ".#nixosConfigurations.$host.config.sops.age.keyFile")"
    case "$key_file" in
      /*) ;;
      *) echo "Unexpected sops.age.keyFile for $host: '$key_file'" >&2; exit 1 ;;
    esac

    # tmpfs, so the private key is never written to this machine's disk.
    work="$(mktemp -d -p /dev/shm os-install.XXXXXXXX)"
    installed=""
    cleanup() {
      if [ -z "$installed" ] && [ -f "$work/backup/.sops.yaml" ]; then
        cp "$work/backup/.sops.yaml" .sops.yaml
        cp "$work/backup/secrets.yaml" "$secrets"
        echo "Install did not finish; restored .sops.yaml and $secrets" >&2
      fi
      rm -rf "$work"
    }
    trap cleanup EXIT

    root="$work/root"
    key="$root$key_file"
    install -d -m 755 "$(dirname "$key")"
    (umask 077 && age-keygen -pq -o "$key" 2>/dev/null)
    # The sops module also writes this on activation; here sops-update-key
    # reads the recipient from it.
    age-keygen -y "$key" > "$key.pub"
    chmod 644 "$key.pub"

    install -d -m 700 "$work/backup"
    cp .sops.yaml "$work/backup/.sops.yaml"
    cp "$secrets" "$work/backup/secrets.yaml"
    # A reinstall wipes the machine and its old key: take the old key's
    # access away (sops-update-key needs only its public key, read from
    # `<path>.pub`) before granting the new one under the same name.
    export HOST="$host"
    old="$(yq '.keys[] | select(anchor == strenv(HOST))' .sops.yaml)"
    if [ -n "$old" ]; then
      echo "$old" > "$work/old-key.pub"
      sops-update-key remove admin "$work/old-key" "$secrets"
    fi
    sops-update-key add admin "$key" "$secrets"

    generate=()
    if [ ! -e "$hardware" ]; then
      generate=(--generate-hardware-config nixos-generate-config "$hardware")
    else
      nix eval --raw ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath" >/dev/null
    fi

    nixos-anywhere "''${generate[@]}" --extra-files "$root" --flake ".#$host" --target-host "$target" "$@"
    installed=1

    # The installed system has a new SSH host key.
    address="''${target#*@}"
    if [ -f ~/.ssh/known_hosts ]; then
      ssh-keygen -R "$address" >/dev/null
    fi

    echo
    echo "Installed $host; its age key is on the new system and can read $secrets."
    echo "Commit .sops.yaml and $secrets."
  '';
}
