{
  flake.modules.homeManager.niri =
    { pkgs, ... }:
    let
      niri-tweaks-src = pkgs.fetchFromGitHub {
        owner = "heyoeyo";
        repo = "niri_tweaks";
        rev = "ec1b61677f443c91607f1f78b1fcefddc568d281"; # follow:branch main
        hash = "sha256-3N3DzHMGT8herVCkVr5JQWCJgxOZq/ta92L3ZptVAXk=";
      };

      niri-tile-to-n = pkgs.writeShellApplication {
        name = "niri-tile-to-n";
        runtimeInputs = [
          pkgs.python3
          pkgs.libnotify
        ];
        text = ''
          exec python3 ${niri-tweaks-src}/niri_tilemod.py -d 5000
        '';
      };
    in
    {
      # Run as a systemd service instead of spawn-at-startup so it auto-restarts
      # when tilemod crashes (e.g. KeyError on monitor hotplug — upstream bug).
      # On restart it re-requests Outputs and picks up the new monitor state.
      systemd.user.services.niri-tile-to-n = {
        Unit = {
          Description = "Niri auto-tiler (tilemod)";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${niri-tile-to-n}/bin/niri-tile-to-n";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
