# Shared by os-install and os-bootstrap, prepended to each script's text.
# Run from the flake root; `nix` comes from PATH, the system's Nix, matching
# its daemon. Needs jq and age on PATH.

die() {
  echo "${0##*/}: $*" >&2
  exit 1
}

# Sets the host's files in this flake (dir, secrets, hardware) and stops if
# the host directory, its secrets file or .sops.yaml is missing.
host_files() {
  dir="profiles/hosts/$1"
  secrets="$dir/secrets/$1.yaml"
  # import-tree skips paths containing "/_", so the raw NixOS module that
  # nixos-generate-config writes doesn't break the flake;
  # flake/nixos.nix imports it into the host.
  hardware="$dir/_hardware-configuration.nix"
  [ -d "$dir" ] || die "no $dir; run from the flake root after creating the host"
  [ -f "$secrets" ] || die "no $secrets; create it with: sops-update admin $secrets"
  [ -f .sops.yaml ] || die "no .sops.yaml; run from the flake root"
}

# Evaluates the host's `hostFacts` (modules/base/nixos/host-facts.nix) once
# into `facts`, and sets key_file and storage (empty without an ephemeral root).
load_host_facts() {
  facts="$(nix --extra-experimental-features 'nix-command flakes' eval --json ".#nixosConfigurations.$1.config.hostFacts")" ||
    die "could not evaluate $1 (error above)"
  key_file="$(jq -r .keyFile <<<"$facts")"
  storage="$(jq -r '.storage.mountPoint // ""' <<<"$facts")"
  case "$key_file" in
    /*) ;;
    *) die "unexpected sops.age.keyFile for $1: '$key_file'" ;;
  esac
}

# Prints the secrets the host needs before users exist that $secrets lacks,
# one per line.
missing_user_secrets() {
  local name
  while IFS= read -r name; do
    NAME="$name" yq -e 'has(strenv(NAME))' "$secrets" >/dev/null || echo "$name"
  done < <(jq -r '.secretsNeededForUsers[]' <<<"$facts")
}

# write_key_pub <key> [command prefix...]: writes <key>.pub, the key's
# recipient, readable by everyone. The prefix (e.g. sudo) runs each step; the
# sops module writes the same file on activation.
write_key_pub() {
  local key="$1"
  shift
  # The inner script expands its own arguments.
  # shellcheck disable=SC2016
  "$@" sh -c '"$1" -y "$2" > "$2.pub" && chmod 644 "$2.pub"' sh "$(command -v age-keygen)" "$key"
}

# make_key <key> [command prefix...]: makes a post-quantum age key, readable
# only by its owner, and its .pub.
make_key() {
  local key="$1"
  shift
  "$@" install -d -m 755 "$(dirname "$key")"
  # age-keygen prints the public key on stderr.
  # shellcheck disable=SC2016
  "$@" sh -c 'umask 077 && "$1" -pq -o "$2" 2>/dev/null' sh "$(command -v age-keygen)" "$key"
  write_key_pub "$key" "$@"
}
