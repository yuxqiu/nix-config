# Fixtures shared by the sops-pq and sops-pq-install VM tests.
{ pkgs }:
rec {
  sshKeys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;
  # The sops module's default sops.age.keyFile.
  keyFile = "/var/lib/sops-nix/key.txt";

  # Proton Pass with one item: the admin key at /root/admin.txt. Logs every
  # call to /tmp/pass-log; a session exists while /tmp/pass-session does.
  fakePassCli = pkgs.writeShellScriptBin "pass-cli" ''
    echo "$*" >> /tmp/pass-log
    case "$1" in
      info) [ -e /tmp/pass-session ] ;;
      login) touch /tmp/pass-session ;;
      logout) rm /tmp/pass-session ;;
      item)
        [ -e /tmp/pass-session ] || { echo "not logged in" >&2; exit 1; }
        [ "$*" = "item view --vault-name sops --item-title age-admin --field key" ] || exit 2
        cat /root/admin.txt
        ;;
      *) exit 2 ;;
    esac
  '';

  # The hostFacts of a host without an ephemeral root and without user secrets. A
  # test writes it, with the fields it changes, to /root/host-facts.json.
  hostFacts = {
    inherit keyFile;
    storage = null;
    keptPaths = [ ];
    secretsNeededForUsers = [ ];
  };
  hostFactsFile = pkgs.writeText "host-facts.json" (builtins.toJSON hostFacts);

  # os-install and os-bootstrap take `nix` from PATH. The test has no flake:
  # the host's hostFacts come from /root/host-facts.json, and evaluating its
  # system succeeds. Every call is logged to /tmp/nix-args; any other
  # attribute fails.
  fakeNix = pkgs.writeShellScriptBin "nix" ''
    printf '%s\n' "$*" >> /tmp/nix-args
    for arg in "$@"; do
      case "$arg" in
        .#nixosConfigurations.*.config.hostFacts) exec cat /root/host-facts.json ;;
        .#nixosConfigurations.*.config.system.build.toplevel.drvPath) echo /nix/store/fake.drv; exit ;;
        .#*) echo "fake nix: unexpected attribute $arg" >&2; exit 1 ;;
      esac
    done
    echo "fake nix: no attribute in: $*" >&2
    exit 1
  '';
}
