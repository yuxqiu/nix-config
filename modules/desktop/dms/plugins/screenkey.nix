{ inputs, ... }:
let
  # The plugin reads keys from `libinput debug-events`, which needs read
  # access to every keyboard. Instead of the input group, it runs that one
  # command through pkexec only while the visualizer is on; the polkit action
  # asks for the admin password (kept for polkit's usual few minutes).
  screenkeyInput = pkgs: inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.dms-screenkey-input;
in
{
  # The polkit action must be installed system-wide.
  flake.modules.nixos.dms =
    { pkgs, ... }:
    {
      environment.systemPackages = [ (screenkeyInput pkgs) ];
    };

  flake.modules.homeManager.dms =
    { pkgs, osConfig, ... }:
    let
      reader = pkgs.lib.getExe (screenkeyInput pkgs).reader;
      pkexec = "${osConfig.security.wrapperDir}/pkexec";
      plugin = (import "${inputs.dms-plugin-registry}/nix/default.nix" { inherit pkgs; }).screenkey;
    in
    {
      programs.dank-material-shell.plugins.screenkey = {
        enable = true;
        settings.visualizerEnabled = false;
        # The registry sets src at normal priority; this is its same plugin, patched.
        src = pkgs.lib.mkForce (
          plugin.overrideAttrs (old: {
            # postFixup: the registry's installPhase skips the postInstall hook.
            # --replace-fail: a plugin update that changes these lines fails the
            # build instead of silently running the tools unprivileged.
            postFixup = (old.postFixup or "") + ''
              listener=$out/shared/InputEventListener.qml
              # Read through the pkexec reader: all keyboards, or one device.
              substituteInPlace $listener \
                --replace-fail '["libinput", "debug-events", "--show-keycodes"]' \
                               '["${pkexec}", "${reader}"]' \
                --replace-fail '["evtest", root.selectedDevicePath]' \
                               '["${pkexec}", "${reader}", root.selectedDevicePath]' \
                --replace-fail 'command: ["libinput", "debug-events"]' \
                               'command: ["${pkexec}", "${reader}"]'
              # Tool and group checks: the reader replaces both tools, and
              # membership of the input group is not needed.
              substituteInPlace $listener \
                --replace-fail '"command -v " + root.requiredTool + " >/dev/null 2>&1"' \
                               '"test -x ${reader}"' \
                --replace-fail '"command -v libinput >/dev/null 2>&1"' \
                               '"test -x ${reader}"' \
                --replace-fail 'grep -qx input' 'true'
            '';
          })
        );
      };
    };
}
