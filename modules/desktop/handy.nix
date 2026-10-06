{
  flake.modules.homeManager.handy =
    { pkgs, ... }:
    let
      inherit (pkgs) handy;

      handy-stt = pkgs.writeShellApplication {
        name = "handy-stt";
        runtimeInputs = [ handy ];
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          readonly MIC_STATE_FILE="/tmp/mic-state"
          readonly HANDY="handy"
          readonly PACTL="${pkgs.pulseaudio}/bin/pactl"

          get_default_mic() {
            "$PACTL" get-default-source
          }
          is_muted() {
            local source="$1"
            "$PACTL" get-source-mute "$source" | grep -q "Mute: yes"
          }
          unmute() {
            local source="$1"
            "$PACTL" set-source-mute "$source" 0 || {
              exit 1
            }
          }
          save_mic_state() {
            local muted="$1"
            printf '%s\n' "$muted" > "$MIC_STATE_FILE"
          }
          restore_mic_state() {
            local source="$1"
            if [[ ! -f "$MIC_STATE_FILE" ]]; then
              return
            fi
            local was_muted
            was_muted=$(<"$MIC_STATE_FILE") || true
            if [[ "$was_muted" == "yes" ]]; then
              "$PACTL" set-source-mute "$source" 1 || true
            fi
            rm -f "$MIC_STATE_FILE"
          }

          mic=$(get_default_mic)

          if [[ -f "$MIC_STATE_FILE" ]]; then
            "$HANDY" --toggle-transcription || {
              restore_mic_state "$mic"
              exit 1
            }
            restore_mic_state "$mic"
          else
            if is_muted "$mic"; then
              save_mic_state "yes"
              unmute "$mic"
            else
              save_mic_state "no"
            fi
            "$HANDY" --toggle-transcription || {
              restore_mic_state "$mic"
              rm -f "$MIC_STATE_FILE"
              exit 1
            }
          fi
        '';
      };
    in
    {
      home.packages = [
        handy
        pkgs.dotool
      ];

      wayland.windowManager.niri.settings.binds."Mod+D" = {
        spawn-sh = "${handy-stt}/bin/handy-stt";
      };
    };
}
