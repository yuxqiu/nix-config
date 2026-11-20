# os-install <host> <[user@]address> [nixos-anywhere flags...]
#
# Installs this flake's NixOS host on a remote machine with nixos-anywhere,
# which wipes it. Run from the flake root. The host's age key is generated on
# its own disk during the install (nixos-install runs activation); the printed
# commands then give it access to its secrets.
{
  writeShellApplication,
  coreutils,
  nixos-anywhere,
  openssh,
}:
writeShellApplication {
  name = "os-install";
  runtimeInputs = [
    coreutils
    nixos-anywhere
    openssh
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

    generate=()
    if [ ! -e "$hardware" ]; then
      generate=(--generate-hardware-config nixos-generate-config "$hardware")
    else
      nix eval --raw ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath" >/dev/null
    fi

    nixos-anywhere "''${generate[@]}" --flake ".#$host" --target-host "$target" "$@"

    # The installed system has a new SSH host key.
    address="''${target#*@}"
    if [ -f ~/.ssh/known_hosts ]; then
      ssh-keygen -R "$address" >/dev/null
    fi

    echo
    echo "Installed $host with its own age key; to give it its secrets:"
    echo "  sops-update-key add admin $target:/var/lib/sops-nix/key.txt $secrets"
    echo "  os-switch $host $target"
  '';
}
