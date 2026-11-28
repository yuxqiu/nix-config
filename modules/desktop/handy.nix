{
  flake.modules.homeManager.handy =
    { pkgs, ... }:
    let
      # Handy downloads models with hf-hub, which reads HF_HOME (default
      # ~/.cache/huggingface; Handy's own portable mode does the same). Point
      # it into Handy's data directory so the model is kept with its settings.
      handy = pkgs.symlinkJoin {
        name = "handy";
        paths = [ pkgs.handy ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/handy \
            --run 'export HF_HOME="''${HF_HOME:-$HOME/.local/share/com.pais.handy/huggingface}"'
        '';
      };

      handy-stt = pkgs.writeShellApplication {
        name = "handy-stt";
        runtimeInputs = [ handy ];
        text = ''
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
            "$PACTL" set-source-mute "$source" 0
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
      # Settings (incl. onboarding and the chosen model), history, recordings
      # and, through HF_HOME above, the downloaded model.
      persistence.directories = [ ".local/share/com.pais.handy" ];
      home.packages = [
        handy
        pkgs.dotool
      ];

      # Keep Handy's in-app "Launch at startup" off: it pins the store path in
      # ~/.config/autostart/Handy.desktop, so it never follows updates.
      systemd.user.services.handy = {
        Unit = {
          Description = "Handy speech-to-text";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${handy}/bin/handy";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      wayland.windowManager.niri.settings.binds."Mod+D" = {
        spawn-sh = "${handy-stt}/bin/handy-stt";
      };
    };
}
