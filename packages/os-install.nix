# os-install <host> <[user@]address> [--keep-state] [nixos-anywhere flags...]
#
# Installs this flake's NixOS host on a remote machine with nixos-anywhere,
# which wipes it. Run from the flake root. The address must be a public IP of
# the machine (or a name resolving only to public IPs): the installer keeps
# only the machine's own network, so any other address is refused.
# Everything handed to the new system is prepared in a private directory on a
# tmpfs (/dev/shm) and is gone when the command exits.
#
# By default the host's age key is made here, granted access to the host's
# secrets, and copied onto the new system with --extra-files at the host's
# `sops.age.keyFile` (under `persistence.storage` on a host with an
# ephemeral root, where that directory is kept), so the host decrypts its
# secrets on first boot. A reinstall replaces the host's previous key. If the
# install fails, .sops.yaml and the secrets file are restored. It stops
# before wiping if the secrets file lacks a secret the host needs before users
# exist (a password hash), since that user would get no password.
#
# With --keep-state (a host with an ephemeral root, reinstalled from the machine
# it is replacing), the state the new system keeps is first copied from the
# running machine: every path in the host's `persistence.keptPaths` (the age
# key's directory among them), as one tar archive that keeps numeric owners,
# modes, ACLs and extended attributes. The key is reused (it must already have access), so
# .sops.yaml does not change. nixos-anywhere then runs without its reboot,
# the archive is unpacked as root into the new persistent filesystem, and the
# machine reboots. It stops before wiping if a kept path or the key is
# missing on the running machine.
{
  writeShellApplication,
  age,
  coreutils,
  gawk,
  getent,
  gnugrep,
  gnutar,
  jq,
  nixos-anywhere,
  openssh,
  sops-tools,
  yq-go,
}:
writeShellApplication {
  name = "os-install";
  # The commands run on the target over ssh are built here on purpose, with
  # every value quoted by `printf %q`.
  excludeShellChecks = [ "SC2029" ];
  runtimeInputs = [
    age
    coreutils
    gawk
    getent
    gnugrep
    gnutar
    jq
    nixos-anywhere
    openssh
    sops-tools
    yq-go
  ];
  text = builtins.readFile ./os-host-lib.sh + ''
    if [ $# -lt 2 ] || [[ "$1" == -* ]] || [[ "$2" == -* ]]; then
      echo "Usage: os-install <host> <[user@]address> [--keep-state] [nixos-anywhere flags...]" >&2
      echo "Example: os-install dracaena root@<ip>" >&2
      exit 1
    fi
    host="$1"
    target="$2"
    shift 2
    keep_state=""
    flags=()
    for arg in "$@"; do
      case "$arg" in
        --keep-state) keep_state=1 ;;
        --phases) [ -z "$keep_state" ] || { echo "--keep-state sets nixos-anywhere's --phases itself" >&2; exit 1; }; flags+=("$arg") ;;
        *) flags+=("$arg") ;;
      esac
    done

    # nixos-anywhere kexecs into its installer, which keeps only the
    # machine's own network: no VPN, nothing reached through a jump host. So
    # the target has to be a public address of the machine itself. Resolve it
    # as ssh would (aliases, HostName), then require every address it
    # resolves to to be public: global IPv4 (not private, CGNAT, loopback,
    # link-local, documentation, multicast or reserved) or global unicast IPv6
    # (2000::/3, not documentation).
    is_public_address() {
      local a="$1"
      if [[ "$a" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        local n=$(( (BASH_REMATCH[1] << 24) + (BASH_REMATCH[2] << 16) + (BASH_REMATCH[3] << 8) + BASH_REMATCH[4] ))
        local range base bits
        for range in 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 \
          192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/3; do
          base="''${range%/*}"
          bits="''${range#*/}"
          IFS=. read -r o1 o2 o3 o4 <<<"$base"
          (( (n >> (32 - bits)) == (((o1 << 24) + (o2 << 16) + (o3 << 8) + o4) >> (32 - bits)) )) && return 1
        done
        return 0
      fi
      case "''${a,,}" in
        2001:db8:* | 2001:0db8:*) return 1 ;;
        [23][0-9a-f][0-9a-f][0-9a-f]:* | [23][0-9a-f][0-9a-f]:* | [23][0-9a-f]:* | [23]:*) return 0 ;;
        *) return 1 ;;
      esac
    }
    ssh_host="$(ssh -G "$target" | awk '$1 == "hostname" { print $2; exit }')"
    [ -n "$ssh_host" ] || die "could not resolve $target with ssh -G"
    mapfile -t addresses < <(getent ahosts "$ssh_host" | awk '{ print $1 }' | sort -u)
    [ "''${#addresses[@]}" -gt 0 ] || die "$target goes to $ssh_host, which does not resolve"
    for address in "''${addresses[@]}"; do
      is_public_address "$address" ||
        die "$target goes to $ssh_host ($address), not a public address; the installer nixos-anywhere boots into has only the machine's own network, so use the machine's public IP"
    done

    # Checked before nixos-anywhere wipes the target, not after.
    host_files "$host"
    load_host_facts "$host"
    mapfile -t missing_secrets < <(missing_user_secrets)
    [ "''${#missing_secrets[@]}" -eq 0 ] || die "$secrets lacks secrets $host needs before users exist, so those users would have no password: ''${missing_secrets[*]}; add them with: sops-update admin $secrets"

    # tmpfs, so the private key and kept state never touch this machine's disk.
    work="$(mktemp -d -p /dev/shm os-install.XXXXXXXX)"
    installed=""
    wiping=""
    cleanup() {
      # Once nixos-anywhere has started, the target may be wiped: the copy of
      # its kept state is then the only one, so keep it rather than delete it.
      if [ -z "$installed" ] && [ -n "$wiping" ] && [ -f "$work/state.tar" ]; then
        kept_archive="$(mktemp -p /dev/shm "os-install-$host-state.XXXXXXXX.tar")"
        mv "$work/state.tar" "$kept_archive"
        chmod 600 "$kept_archive"
        echo "Install did not finish and $target may be wiped. Its kept state is in $kept_archive;" >&2
        echo "once the new system is installed and mounted at /mnt, restore it with:" >&2
        echo "  ssh $target \"tar -C /mnt$storage --numeric-owner --same-owner --xattrs --acls -xpf -\" < $kept_archive" >&2
      fi
      if [ -z "$installed" ] && [ -f "$work/backup/.sops.yaml" ]; then
        cp "$work/backup/.sops.yaml" .sops.yaml
        cp "$work/backup/secrets.yaml" "$secrets"
        echo "Install did not finish; restored .sops.yaml and $secrets" >&2
      fi
      rm -rf "$work"
    }
    trap cleanup EXIT

    if [ -n "$keep_state" ]; then
      [ -n "$storage" ] || die "--keep-state needs a host with an ephemeral root (persistence.storage)"
      mapfile -t kept < <(jq -r '.keptPaths[]' <<<"$facts")
      [ "''${#kept[@]}" -gt 0 ] || die "$host keeps no paths"

      quoted="$(printf '%q ' "''${kept[@]}")"
      missing="$(ssh "$target" "for p in $quoted; do [ -e \"\$p\" ] || [ -L \"\$p\" ] || echo \"\$p\"; done")" ||
        die "could not reach $target"
      [ -z "$missing" ] || die "kept paths missing on $target (create them there or drop them from the config):
    $missing"
      # The key's directory is kept, so it is at keyFile on the running
      # machine with or without an ephemeral root.
      ssh "$target" "test -s $(printf '%q' "$key_file")" || die "no age key on $target at $key_file"

      # Member names are relative to /, and unpack relative to the storage.
      members=()
      for p in "''${kept[@]}"; do members+=("''${p#/}"); done
      # The machine keeps running while this is read. GNU tar exits 1 when a
      # file changes as it reads it: fine for live logs (journald rotates a
      # damaged journal file), not for keys or service state, so anything
      # else that changed stops here. 2 or more is a fatal tar error.
      status=0
      ssh "$target" "tar -C / --numeric-owner --xattrs --acls -cpf - -- $(printf '%q ' "''${members[@]}")" > "$work/state.tar" 2> "$work/tar.err" ||
        status=$?
      changed="$(sed -n 's/^tar: \(.*\): file changed as we read it$/\1/p' "$work/tar.err")"
      if [ "$status" -eq 1 ] && [ -n "$changed" ] && ! grep -v '^var/log/' <<<"$changed" | grep -q . && [ "$(grep -vc 'file changed as we read it' "$work/tar.err")" -eq 0 ]; then
        echo "Logs changed while being copied (kept as read): $(tr '\n' ' ' <<<"$changed")"
      elif [ "$status" -ne 0 ]; then
        cat "$work/tar.err" >&2
        die "could not copy the kept state from $target (files other than logs changed, or tar failed; nothing was wiped)"
      fi
      install -d -m 700 "$work/key"
      tar -C "$work/key" -xf "$work/state.tar" "''${key_file#/}"
      recipient="$(age-keygen -y "$work/key/''${key_file#/}")"
      grep -Fq "$recipient" .sops.yaml || die "the kept key on $target has no access to $secrets; grant it with sops-update-key first"
      echo "Copied $(du -h "$work/state.tar" | cut -f1) of kept state from $target; reusing its age key."
      anywhere=(--phases "kexec,disko,install")
    else
      root="$work/root"
      # nixos-anywhere unpacks these under the new system's /, which is wiped
      # at boot on a host with an ephemeral root; the key's directory is kept, so
      # it goes on the storage.
      key="$root$storage$key_file"
      # sops-update-key reads the recipient from the key's .pub.
      make_key "$key"

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
      anywhere=(--extra-files "$root")
    fi

    generate=()
    if [ ! -e "$hardware" ]; then
      generate=(--generate-hardware-config nixos-generate-config "$hardware")
    else
      nix eval --raw ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath" >/dev/null
    fi

    wiping=1
    nixos-anywhere "''${generate[@]}" "''${anywhere[@]}" --flake ".#$host" --target-host "$target" "''${flags[@]}"

    if [ -n "$keep_state" ]; then
      # The machine is still in nixos-anywhere's installer with the new system
      # mounted at /mnt; unpack as root so owners and modes come back as they
      # were, then reboot into it.
      ssh "$target" "tar -C $(printf '%q' "/mnt$storage") --numeric-owner --same-owner --xattrs --acls -xpf -" < "$work/state.tar" ||
        die "could not unpack the kept state on $target; it is still in the installer, nothing rebooted"
      # systemd unmounts everything itself; `umount -R /mnt` fails when /mnt
      # is not a mount point itself, as with root on tmpfs.
      ssh "$target" "systemctl reboot" || true
    fi
    installed=1

    # The installed system has a new SSH host key, unless the old ones were
    # kept.
    address="''${target#*@}"
    if [ -f ~/.ssh/known_hosts ] && ! { [ -n "$keep_state" ] && printf '%s\n' "''${kept[@]}" | grep -q '^/etc/ssh/ssh_host_'; }; then
      ssh-keygen -R "$address" >/dev/null
    fi

    echo
    if [ -n "$keep_state" ]; then
      echo "Installed $host with its kept state and age key; .sops.yaml is unchanged."
    else
      echo "Installed $host; its age key is on the new system and can read $secrets."
      echo "Commit .sops.yaml and $secrets."
    fi
  '';
}
