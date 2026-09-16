{
  flake.modules.nixos.bt-proximity-lock =
    { pkgs, ... }:
    let
      poll-interval-seconds = 5;
      misses-before-lock = 3;

      bt-proximity-lock = pkgs.writeShellApplication {
        name = "bt-proximity-lock";
        runtimeInputs = [
          pkgs.bluez
          pkgs.systemd
          pkgs.gawk
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
          # Never count misses until we've seen one confirmed "connected"
          # reading. Without this, restarting this service (e.g. on
          # nixos-rebuild switch) or unlocking the session races Bluetooth
          # reconnection: the phone reads as absent for a few seconds and
          # we'd lock again before it has a chance to reconnect.
          armed=false
          prev_locked_hint=""

          while true; do
            # Find the seat-attached (graphical) session, not any manager
            # sessions, without hardcoding a username.
            session=$(loginctl list-sessions --no-legend 2>/dev/null | awk '$4 != "-" {print $1; exit}')
            if [ -n "$session" ]; then
              locked_hint=$(loginctl show-session "$session" -p LockedHint --value 2>/dev/null || true)
              if [ "$prev_locked_hint" = "yes" ] && [ "$locked_hint" = "no" ]; then
                armed=false
                misses=0
                locked_for_absence=false
              fi
              prev_locked_hint="$locked_hint"
            fi

            # BlueZ keeps reporting the last-known "Connected: no" for a
            # device even with the adapter powered off, indistinguishable
            # from the phone actually being out of range. Only treat
            # absence as meaningful while the adapter itself is up.
            if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
              if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
                misses=0
                locked_for_absence=false
                armed=true
              elif [ "$armed" = true ]; then
                misses=$((misses + 1))
                if [ "$misses" -ge ${toString misses-before-lock} ] && [ "$locked_for_absence" = false ]; then
                  loginctl lock-sessions
                  locked_for_absence=true
                fi
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
