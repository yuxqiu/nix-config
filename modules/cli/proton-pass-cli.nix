{
  flake.modules.homeManager.proton-pass-cli =
    { pkgs, ... }:
    let
      pass-ssh = pkgs.writeShellApplication {
        name = "pass-ssh";
        runtimeInputs = [ pkgs.proton-pass-cli ];
        text = ''
          set -euo pipefail

          if ! pass-cli info &>/dev/null; then
            pass-cli login || exit 1
          fi

          pass-cli ssh-agent load --vault-name ssh
          pass-cli logout
        '';
      };
    in
    {
      home.packages = [
        pass-ssh
        pkgs.proton-pass-cli
      ];
    };
}
