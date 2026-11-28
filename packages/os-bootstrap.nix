# os-bootstrap <host>
#
# Prepares the machine it runs on, already running NixOS (e.g. from the
# graphical installer), to switch to this flake's <host>. Run from a checkout
# of the flake, as a user who can sudo. Safe to rerun; each step is skipped
# once done:
#
#   1. Makes the host's age key, where the host's config will read it
#      (`sops.age.keyFile`). On a host with an ephemeral root the key's directory
#      is kept: it is bind-mounted from the same path on the persistent
#      filesystem, so the key goes under wherever that filesystem is mounted
#      now: `/` on a machine converted in place (its root becomes the
#      persistent filesystem), `persistence.storage` on one already laid out
#      or switched, or any other mount point. Stops if it is not mounted.
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
  jq,
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
    jq
    sops-tools
    util-linux
    yq-go
  ];
  text = builtins.readFile ./os-host-lib.sh + ''
    if [ $# -ne 1 ] || [[ "$1" == -* ]]; then
      echo "Usage: os-bootstrap <host>" >&2
      exit 1
    fi
    host="$1"
    host_files "$host"
    # `sudo` comes from PATH: the running system's.
    load_host_facts "$host"

    # 1. The key, on the filesystem that will hold it once the host's config
    # is running.
    key="$key_file"
    if [ -n "$storage" ]; then
      # The filesystem the config mounts at $storage: its device, and for a
      # btrfs subvolume the subvolume, which findmnt reports as FSROOT (bind
      # mounts of its directories have other FSROOTs).
      device="$(jq -r '.storage.fileSystem.device // ""' <<<"$facts")"
      [ -n "$device" ] || die "the config mounts no filesystem with a device at $storage (fileSystems.\"$storage\")"
      fs_root=/
      mapfile -t opts < <(jq -r '.storage.fileSystem.options[]' <<<"$facts")
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
      key="$base$key_file"
      echo "Host with an ephemeral root: its persistent filesystem is mounted at ''${mounted_at[0]}, so the key goes at $key."
    fi
    if sudo test -e "$key"; then
      sudo test -e "$key.pub" || write_key_pub "$key" sudo
      echo "1. Host key exists: $key"
    else
      make_key "$key" sudo
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
    mapfile -t missing < <(missing_user_secrets)
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
