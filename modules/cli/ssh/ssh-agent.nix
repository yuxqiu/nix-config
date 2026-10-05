{ inputs, ... }:
{
  config.flake.modules.homeManager.ssh-agent =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      clearSshKeys = pkgs.writeShellScript "clear-ssh-keys" ''
        #!${pkgs.bash}/bin/bash
        set +e

        sock="$XDG_RUNTIME_DIR/${config.services.ssh-agent.socket}"
        if [ -S "$sock" ]; then
          SSH_AUTH_SOCK="$sock" ${pkgs.openssh}/bin/ssh-add -D 2>/dev/null || true
        fi
      '';

      watchSuspend = pkgs.writeShellScript "watch-suspend-and-clear-ssh-keys" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        ${pkgs.glib}/bin/gdbus monitor \
          --system \
          --dest org.freedesktop.login1 \
          --object-path /org/freedesktop/login1 \
        | while read -r line; do
            case "$line" in
              *PrepareForSleep*true*)
                ${clearSshKeys}
                ;;
            esac
          done
      '';
    in
    {
      home.packages = [ inputs.ssh-agent-ac.packages.${pkgs.stdenv.system}.ssh-agent-ac ];

      services.ssh-agent = {
        enable = true;

        defaultMaximumIdentityLifetime = null;
      };

      # Linux: systemd integration
      systemd.user.services.ssh-agent = {
        Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
        Unit = {
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };

        Service.Environment = [
          "SSH_ASKPASS=${pkgs.seahorse}/libexec/seahorse/ssh-askpass"
        ];
      };

      systemd.user.services.ssh-agent-suspend-clear = {
        Unit = {
          Description = "Clear SSH agent keys before suspend";
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${watchSuspend}";
          Restart = "always";
          RestartSec = 1;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      wayland.windowManager.niri.settings._children = lib.mkAfter [
        {
          window-rule = {
            match._props."app-id" = "ssh-askpass";
            background-effect.blur = true;
            opacity = 0.8;
          };
        }
      ];

      # Darwin: launchd integration
      launchd.agents.ssh-agent.config.EnvironmentVariables = {
        SSH_ASKPASS = "${pkgs.ssh-askpass-fullscreen}/bin/ssh-askpass-fullscreen";
      };
    };
}
