{
  flake.modules.homeManager.ssh-copy-id =
    { pkgs, config, ... }:
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "ssh-copy-id-general";
          runtimeInputs = with pkgs; [
            coreutils
            openssh
          ];
          text = ''
            set -euo pipefail

            tmp_key="$(mktemp --suffix=.pub)"
            trap 'rm -f "$tmp_key"' EXIT
            printf '%s\n' '${config.identity.keys."general-ssh"}' > "$tmp_key"
            exec ssh-copy-id -f -i "$tmp_key" "$@"
          '';
        })
      ];
    };
}
