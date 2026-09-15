{
  flake.modules.homeManager.niri =
    { pkgs, ... }:
    let
      niri-tweaks-src = pkgs.fetchFromGitHub {
        owner = "heyoeyo";
        repo = "niri_tweaks";
        rev = "9f43651be8ddb5f16f7c80daeb15b8c5dcd4dd23"; # follow:branch main
        hash = "sha256-a1QSTfcO1xC1OS7THxXEeu/s68Lb7cf0a1lQ8epVJ58=";
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
      # Workaround: niri's config generator (writeText) doesn't track
      # string-interpolated store paths as runtime dependencies, so this
      # would get GC'd. Remove once upstream niri HM module fixes this.
      home.packages = [ niri-tile-to-n ];

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
