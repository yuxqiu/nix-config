{
  flake.modules.nixos.yuxqiu-cedrus =
    { pkgs, ... }:
    let
      poll-interval-seconds = 5;
      misses-before-lock = 3;

      bt-proximity-lock = pkgs.writeShellApplication {
        name = "bt-proximity-lock";
        runtimeInputs = [
          pkgs.bluez
          pkgs.systemd
        ];
        text = ''
          set -euo pipefail

          # The tracked device's MAC lives in a sops secret under a
          # deliberately generic key: it's a stable identifier for a
          # specific device, so its key name shouldn't advertise what
          # it's for in the (public, plaintext-keyed) sops file.
          mac=$(cat /run/secrets/aux_token)
          misses=0
          locked_for_absence=false

          while true; do
            if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
              misses=0
              locked_for_absence=false
            else
              misses=$((misses + 1))
              if [ "$misses" -ge ${toString misses-before-lock} ] && [ "$locked_for_absence" = false ]; then
                loginctl lock-sessions
                locked_for_absence=true
              fi
            fi
            sleep ${toString poll-interval-seconds}
          done
        '';
      };
    in
    {
      # Runs as its own unprivileged system account rather than the
      # interactive user, so anything running as that user can't read the
      # device secret just by sharing its UID.
      users.users.bt-proximity-lock = {
        isSystemUser = true;
        group = "bt-proximity-lock";
      };
      users.groups.bt-proximity-lock = { };

      sops.secrets."aux_token" = {
        owner = "bt-proximity-lock";
        mode = "0400";
      };

      # loginctl lock-sessions requires auth_admin by default; grant it to
      # this one service account instead of running the daemon as root.
      security.polkit.extraConfig = ''
        polkit.addRule(function (action, subject) {
          if (
            action.id == "org.freedesktop.login1.lock-sessions" &&
            subject.user == "bt-proximity-lock"
          ) {
            return polkit.Result.YES;
          }
        });
      '';

      systemd.services.bt-proximity-lock = {
        description = "Lock the session when a paired Bluetooth device goes out of range";
        after = [ "bluetooth.target" ];
        wants = [ "bluetooth.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          User = "bt-proximity-lock";
          Group = "bt-proximity-lock";
          ExecStart = "${bt-proximity-lock}/bin/bt-proximity-lock";
          Restart = "on-failure";
          RestartSec = 5;

          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      };
    };
}
