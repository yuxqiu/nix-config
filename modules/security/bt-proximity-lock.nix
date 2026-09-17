{
  flake.modules.nixos.bt-proximity-lock =
    { pkgs, ... }:
    let
      # BlueZ never invalidates a bonded device's cached RSSI on its own
      # (its "temporary device" expiry only applies to unpaired devices),
      # so a stale reading looks identical to a live one. The signal's
      # value is the only real freshness signal: react to it weakening,
      # not just to it existing.
      rssi-threshold-dbm = -80;
      # A single weak reading near the threshold is often just multipath
      # fading or body-blocking, not the device actually leaving - confirm
      # it with a few quick active reads rather than trusting one sample.
      confirm-poll-interval-seconds = 3;
      confirm-polls-required = 2;
      loginctl = "${pkgs.systemd}/bin/loginctl";

      bt-proximity-lock =
        pkgs.writers.writePython3Bin "bt-proximity-lock"
          {
            libraries = [ pkgs.python3Packages.dbus-next ];
            flakeIgnore = [
              "E501" # long lines
            ];
          }
          ''
            import asyncio
            import subprocess
            import sys

            from dbus_next.aio import MessageBus
            from dbus_next.constants import BusType

            # The tracked device's MAC lives in a sops secret under a
            # deliberately generic key: it's a stable identifier for a specific
            # device, so its key name shouldn't advertise what it's for in the
            # (public, plaintext-keyed) sops file.
            MAC_FILE = "/run/secrets/aux_token"
            RSSI_THRESHOLD_DBM = ${toString rssi-threshold-dbm}
            CONFIRM_POLL_INTERVAL_SECONDS = ${toString confirm-poll-interval-seconds}
            CONFIRM_POLLS_REQUIRED = ${toString confirm-polls-required}
            LOGINCTL = "${loginctl}"


            def read_mac():
                with open(MAC_FILE) as f:
                    return f.read().strip()


            def mac_to_device_path(adapter_path, mac):
                return f"{adapter_path}/dev_{mac.replace(':', '_')}"


            async def find_adapter_path(bus):
                introspection = await bus.introspect("org.bluez", "/")
                root = bus.get_proxy_object("org.bluez", "/", introspection)
                manager = root.get_interface("org.freedesktop.DBus.ObjectManager")
                objects = await manager.call_get_managed_objects()
                for path, ifaces in objects.items():
                    if "org.bluez.Adapter1" in ifaces:
                        return path
                raise RuntimeError("no Bluetooth adapter found")


            def is_present(rssi):
                return rssi is not None and rssi.value >= RSSI_THRESHOLD_DBM


            async def main():
                mac = read_mac()
                bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
                adapter_path = await find_adapter_path(bus)
                device_path = mac_to_device_path(adapter_path, mac)

                adapter_introspection = await bus.introspect("org.bluez", adapter_path)
                adapter_obj = bus.get_proxy_object("org.bluez", adapter_path, adapter_introspection)
                adapter = adapter_obj.get_interface("org.bluez.Adapter1")
                adapter_props = adapter_obj.get_interface("org.freedesktop.DBus.Properties")

                device_introspection = await bus.introspect("org.bluez", device_path)
                device_obj = bus.get_proxy_object("org.bluez", device_path, device_introspection)
                device_props = device_obj.get_interface("org.freedesktop.DBus.Properties")

                # Presence is tri-state, not a bool: only a present ->
                # absent transition ever locks, and only once - a fresh
                # start ("unknown") can't lock off a stale reading, and
                # staying absent can't repeat-lock. A single weak RSSI
                # reading only starts a short burst of active confirmation
                # reads rather than locking immediately (one weak sample is
                # often just multipath fading, not a real departure) or
                # waiting for a second natural signal (gaps of up to ~90s
                # between readings are normal for a stationary device). A
                # device that goes silent without ever reporting one weak
                # reading at all (e.g. Bluetooth switched off outright)
                # isn't detected - there's no fallback timeout for that.
                state = {"presence": "unknown", "confirming": False}

                async def confirm_departure():
                    if state["confirming"]:
                        return
                    state["confirming"] = True
                    try:
                        weak_count = 0
                        while True:
                            await asyncio.sleep(CONFIRM_POLL_INTERVAL_SECONDS)
                            try:
                                rssi = (
                                    await device_props.call_get_all("org.bluez.Device1")
                                ).get("RSSI")
                            except Exception:
                                rssi = None
                            if is_present(rssi):
                                state["presence"] = "present"
                                return
                            weak_count += 1
                            if weak_count >= CONFIRM_POLLS_REQUIRED:
                                if state["presence"] == "present":
                                    print(
                                        f"locking: RSSI={rssi.value if rssi else None} "
                                        f"confirmed weak over {weak_count} active reads",
                                        file=sys.stderr,
                                        flush=True,
                                    )
                                    subprocess.run(
                                        [LOGINCTL, "lock-sessions"], check=False
                                    )
                                state["presence"] = "absent"
                                return
                    finally:
                        state["confirming"] = False

                def on_device_props_changed(interface, changed, invalidated):
                    if interface != "org.bluez.Device1":
                        return
                    if "RSSI" not in changed:
                        return
                    if is_present(changed["RSSI"]):
                        state["presence"] = "present"
                    elif state["presence"] == "present" and not state["confirming"]:
                        asyncio.create_task(confirm_departure())

                device_props.on_properties_changed(on_device_props_changed)

                # BlueZ ties a discovery session to the client that
                # requested it, so keeping this process's connection open
                # is what keeps RSSI updates flowing. Re-issued when the
                # adapter is (re-)powered on, since that drops any
                # existing session along with the radio itself.
                async def ensure_discovery():
                    try:
                        discovering = (
                            await adapter_props.call_get("org.bluez.Adapter1", "Discovering")
                        ).value
                        if not discovering:
                            await adapter.call_start_discovery()
                    except Exception:
                        pass

                def on_adapter_props_changed(interface, changed, invalidated):
                    if interface != "org.bluez.Adapter1":
                        return
                    powered = changed.get("Powered")
                    if powered is not None and powered.value:
                        asyncio.create_task(ensure_discovery())

                adapter_props.on_properties_changed(on_adapter_props_changed)

                # Seed from whatever BlueZ already knows, in case the
                # device was already visible before this started.
                try:
                    current = await device_props.call_get_all("org.bluez.Device1")
                    if is_present(current.get("RSSI")):
                        state["presence"] = "present"
                except Exception:
                    pass

                try:
                    if (
                        await adapter_props.call_get("org.bluez.Adapter1", "Powered")
                    ).value:
                        await ensure_discovery()
                except Exception:
                    pass

                # Everything from here is driven by the signal handlers
                # above; nothing left to do proactively.
                await asyncio.Event().wait()


            asyncio.run(main())
          '';
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
