{ inputs, ... }:
{
  flake.modules.nixos.edgepad = {
    imports = [ inputs.edgepad.nixosModules.default ];

    services.edgepad.enable = true;

    # Tag edgepad's virtual touchpad as external so libinput doesn't
    # disable it when the laptop lid is closed.
    services.udev.extraRules = ''
      ACTION=="add", KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_INPUT_TOUCHPAD}=="1", ATTRS{name}=="edgepad virtual touchpad", ENV{ID_INPUT_TOUCHPAD_INTEGRATION}="external"
    '';
  };

  flake.modules.homeManager.edgepad =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.services.edgepad;
      edgepadExe = lib.getExe cfg.package;
      configPath = "${config.xdg.configHome}/edgepad/edgepad.toml";
      udevadm = "${pkgs.systemd}/bin/udevadm";
      inherit (inputs.self.packages.${pkgs.stdenv.hostPlatform.system}) dms-brightness;

      # Pick external (USB/Bluetooth) touchpad if present, fall back to internal.
      # Supervises edgepad and switches devices on hot-plug via inotify.
      edgepad-wrapper = pkgs.writeShellApplication {
        name = "edgepad-wrapper";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.inotify-tools
        ];
        text = ''
          pick_device() {
            local external=""
            local internal=""
            for node in /dev/input/event*; do
              [ -e "$node" ] || continue
              props=$(${udevadm} info --query=property "$node" 2>/dev/null || true)
              echo "$props" | grep -q 'ID_INPUT_TOUCHPAD=1' || continue
              # Skip edgepad's own virtual device (DEVPATH=/devices/virtual/input/...)
              echo "$props" | grep -q 'DEVPATH=/devices/virtual/input/' && continue
              if echo "$props" | grep -qE 'ID_BUS=(usb|bluetooth)'; then
                external="$node"
              else
                internal="$node"
              fi
            done
            echo "''${external:-$internal}"
          }

          current_device=""
          edgepad_pid=""
          edgepad_fifo=""
          reader_pid=""

          # Stops edgepad and its output reader, if running, and removes the FIFO.
          stop_edgepad() {
            [ -n "$reader_pid" ] && kill "$reader_pid" 2>/dev/null || true
            [ -n "$edgepad_pid" ] && kill "$edgepad_pid" 2>/dev/null || true
            [ -n "$edgepad_pid" ] && wait "$edgepad_pid" 2>/dev/null || true
            [ -n "$edgepad_fifo" ] && rm -f "$edgepad_fifo"
            reader_pid=""
            edgepad_pid=""
            edgepad_fifo=""
          }

          watcher_pid=""
          cleanup() {
            [ -n "$watcher_pid" ] && kill "$watcher_pid" 2>/dev/null || true
            stop_edgepad
            exit 0
          }
          trap cleanup TERM INT

          forward_reload() {
            [ -n "$edgepad_pid" ] && kill -HUP "$edgepad_pid" 2>/dev/null || true
          }
          trap forward_reload HUP

          # Starts edgepad on the picked device. Fails, leaving nothing
          # running, when there is no touchpad, fingers are on it, or edgepad
          # exits before it is ready.
          # shellcheck disable=SC2094
          start_edgepad() {
            current_device=$(pick_device)
            if [ -z "$current_device" ]; then
              return 1
            fi

            # FIFO to read edgepad's output; $! gives edgepad's real PID
            edgepad_fifo=$(mktemp -u /tmp/edgepad-fifo.XXXXXX)
            mkfifo "$edgepad_fifo"
            ${edgepadExe} daemon --config "${configPath}" --device "$current_device" >"$edgepad_fifo" 2>&1 &
            edgepad_pid=$!

            # Read edgepad output line-by-line, react to startup messages
            while IFS= read -r line; do
              echo "$line" >&2
              case "$line" in
                *"already touched"*)
                  stop_edgepad
                  return 1
                  ;;
                *"ready notification sent"*)
                  # edgepad is ready — background reader keeps FIFO drained
                  while IFS= read -r line; do
                    echo "$line" >&2
                  done <"$edgepad_fifo" &
                  reader_pid=$!
                  return 0
                  ;;
              esac
            done <"$edgepad_fifo"

            # edgepad exited before printing either message
            stop_edgepad
            return 1
          }

          # Stops whatever runs and starts edgepad again, retrying every
          # second until a touchpad is found and no fingers are on it.
          restart_edgepad() {
            stop_edgepad
            until start_edgepad; do
              sleep 1
            done
          }

          restart_edgepad

          # Watch /dev/input for device add/remove events.
          # If edgepad crashes without a device change, systemd's
          # Restart=on-failure restarts the whole wrapper.
          # Read from a process substitution, not a pipe, so the loop runs in
          # this shell: restarts update the edgepad_pid the traps use, and
          # the traps run while `read` waits for the next event.
          exec {events}< <(inotifywait -m -q -e create,delete --format '%e %f' /dev/input)
          watcher_pid=$!
          while IFS=' ' read -r event name <&"$events"; do
            # The kernel creates a node before udev has run its rules and
            # stored the device's properties (ID_INPUT_TOUCHPAD, ID_BUS),
            # which pick_device reads, so wait until udev has initialized a
            # new event node. Bounded by udev's own event timeout (180 s
            # default, udev.conf(5)), after which udevd abandons the event
            # and the device never initializes. A node already gone again
            # (a stale event) is not waited for.
            if [ "$event" = CREATE ] && [[ "$name" == event* ]] && [ -e "/dev/input/$name" ]; then
              ${udevadm} wait --initialized=yes --timeout=180 "/dev/input/$name" ||
                echo "edgepad-wrapper: udev did not initialize /dev/input/$name" >&2
            fi

            # edgepad died (e.g. device removed), or a different device
            # appeared: restart on the device picked now.
            if ! kill -0 "$edgepad_pid" 2>/dev/null; then
              restart_edgepad
              continue
            fi
            new_device=$(pick_device)
            if [ -n "$new_device" ] && [ "$new_device" != "$current_device" ]; then
              restart_edgepad
            fi
          done
        '';
      };

    in
    {
      imports = [ inputs.edgepad.homeManagerModules.default ];

      services.edgepad = {
        enable = true;
        device = "auto";
        edgeWidth = 0.05;
        tapMinDurationMs = 40;
        swipeMinDistance = 0.02;

        gestures = [
          {
            zone = "top";
            direction = "tap";
            action = [
              "${pkgs.playerctl}/bin/playerctl"
              "play-pause"
            ];
          }
        ];

        sliders = [
          {
            zone = "left";
            up = [
              "${pkgs.pamixer}/bin/pamixer"
              "-i"
              "1"
            ];
            down = [
              "${pkgs.pamixer}/bin/pamixer"
              "-d"
              "1"
            ];
          }
          {
            zone = "right";
            up = [
              (lib.getExe dms-brightness)
              "increment"
            ];
            down = [
              (lib.getExe dms-brightness)
              "decrement"
            ];
          }
        ];
      };

      systemd.user.services.edgepad.Service = {
        ExecStart = lib.mkForce (lib.getExe edgepad-wrapper);
        # edgepad runs as a child of the wrapper; allow it to send sd_notify
        NotifyAccess = lib.mkForce "all";
      };
    };
}
