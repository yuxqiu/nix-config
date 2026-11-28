{
  flake.modules.homeManager.proton-pass-cli =
    { pkgs, ... }:
    let
      pass-ssh = pkgs.writeShellApplication {
        name = "pass-ssh";
        runtimeInputs = [ pkgs.proton-pass-cli ];
        text = ''
          if ! pass-cli info &>/dev/null; then
            pass-cli login
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
