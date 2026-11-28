{
  flake.modules.homeManager.niri =
    { lib, pkgs, ... }:
    let
      niri-tweaks-src = pkgs.fetchFromGitHub {
        owner = "heyoeyo";
        repo = "niri_tweaks";
        rev = "cc1bb125143033206f1784f2483e6c48d2f436c7"; # follow:branch main
        hash = "sha256-PNGFsN48bPEFk7F/EzMcLutUzlZXNHv58kve4XCzkTU=";
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

      # tilemod reads niri's outputs at startup and on ConfigLoaded only, then
      # looks up each workspace's output with this unguarded index, which
      # raises KeyError for a monitor plugged in later.
      staleOutputLookup = ''all_monitor_dict[curr_wspace_dict["output"]]'';
    in
    {
      warnings =
        lib.optional
          (!lib.hasInfix staleOutputLookup (builtins.readFile "${niri-tweaks-src}/niri_tilemod.py"))
          ''
            niri-tile-to-n.nix: niri_tilemod.py no longer contains ${staleOutputLookup}.
            If it now handles monitor hotplug, remove Restart and RestartSec from
            systemd.user.services.niri-tile-to-n, the comment above them, staleOutputLookup
            and this warning.
          '';

      # Run as a systemd service instead of spawn-at-startup so it restarts
      # when tilemod crashes on monitor hotplug (staleOutputLookup above).
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
