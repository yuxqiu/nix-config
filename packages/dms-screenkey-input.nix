{
  lib,
  writeShellApplication,
  runCommand,
  libinput,
  util-linux,
}:
let
  # Runs as root under pkexec. It accepts no arguments or one evdev node, so
  # the polkit grant can't be used to run anything else.
  reader = writeShellApplication {
    name = "dms-screenkey-input";
    runtimeInputs = [
      libinput
      util-linux
    ];
    text = ''
      if [[ ! "''${PKEXEC_UID:-}" =~ ^[0-9]+$ ]]; then
        echo "dms-screenkey-input: run through pkexec" >&2
        exit 2
      fi
      device_args=()
      if [ $# -eq 1 ] && [[ "$1" =~ ^/dev/input/event[0-9]+$ ]]; then
        device_args=(--device "$1")
      elif [ $# -ne 0 ]; then
        echo "usage: pkexec dms-screenkey-input [/dev/input/eventN]" >&2
        exit 2
      fi
      # Hand the real UID back to the caller while keeping root as the
      # effective UID to open devices. The kernel lets a process signal
      # another whose real UID matches its own, so the shell's SIGTERM stops
      # the reader; ptrace and /proc/<pid>/fd still need the effective UID and
      # stay closed to the caller.
      exec setpriv --ruid "$PKEXEC_UID" -- libinput debug-events --show-keycodes "''${device_args[@]}"
    '';
  };
in
runCommand "dms-screenkey-input"
  {
    meta.mainProgram = "dms-screenkey-input";
    passthru = { inherit reader; };
  }
  ''
    mkdir -p $out/bin $out/share/polkit-1/actions
    ln -s ${lib.getExe reader} $out/bin/dms-screenkey-input
    cat > $out/share/polkit-1/actions/dms-screenkey-input.policy <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
      "http://www.freedesktop.org/software/polkit/policyconfig-1.dtd">
    <policyconfig>
      <action id="local.dms-screenkey-input">
        <description>Show keystrokes on screen</description>
        <message>Authentication is required to read keyboard input for the on-screen keys</message>
        <defaults>
          <allow_any>no</allow_any>
          <allow_inactive>no</allow_inactive>
          <allow_active>auth_admin_keep</allow_active>
        </defaults>
        <annotate key="org.freedesktop.policykit.exec.path">${lib.getExe reader}</annotate>
      </action>
    </policyconfig>
    EOF
  ''
