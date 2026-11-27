{ inputs, ... }:
{
  flake.modules.homeManager.paseo =
    { pkgs, ... }:
    {
      # The desktop app's own state; ~/.paseo is the daemon's (nixos.paseo).
      persistence.directories = [ ".config/Paseo" ];
      home.packages = [ pkgs.paseo-desktop ];
    };

  flake.modules.nixos.paseo =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Git config for everything agents run, layered over the user's own via
      # GIT_CONFIG_* (highest precedence short of `-c`). The user's signing key
      # lives only in their SSH agent, so agent commits are left unsigned for
      # the user to re-sign on review.
      agentGitConfig = [
        [
          "commit.gpgSign"
          "false"
        ]
        [
          "tag.gpgSign"
          "false"
        ]
      ];
    in
    {
      # nixpkgs packages paseo but ships no module (NixOS/nixpkgs#587943 adds
      # one); upstream's defaults to pkgs.paseo. Once nixpkgs has it, evaluation
      # fails with services.paseo "already declared": switch to nixpkgs' module
      # then, and drop the `paseo` flake input.
      imports = [ "${inputs.paseo}/nix/module.nix" ];

      # The daemon's agent data, config and logs (PASEO_HOME).
      persistence.directories = [
        {
          directory = config.services.paseo.dataDir;
          inherit (config.services.paseo) user group;
          mode = "0700";
        }
      ];

      services.paseo = {
        enable = true;
        group = "users";
        listenAddress = "127.0.0.1";
        # Clients reach each daemon over the tailnet (tailscale serve), not
        # through the hosted relay.
        relay.enable = false;
        # Set here because the module rewrites config.json on every start,
        # discarding changes made in the UI.
        # Dictation and voice mode run on local speech models the daemon
        # downloads into $PASEO_HOME/models (about 1 GB); neither is used.
        settings.features = {
          dictation.enabled = false;
          voiceMode.enabled = false;
        };
        settings.daemon = {
          # Paseo's MCP tools, passed only to agents Paseo itself launches.
          mcp.injectIntoAgents = true;
          browserTools.enabled = false;
        };
        environment = {
          GIT_CONFIG_COUNT = toString (builtins.length agentGitConfig);
        }
        // lib.listToAttrs (
          lib.concatLists (
            lib.imap0 (i: kv: [
              (lib.nameValuePair "GIT_CONFIG_KEY_${toString i}" (builtins.elemAt kv 0))
              (lib.nameValuePair "GIT_CONFIG_VALUE_${toString i}" (builtins.elemAt kv 1))
            ]) agentGitConfig
          )
        );
      };

      # Agents and Paseo itself call `gh` (PRs, CI); the daemon's PATH
      # includes the system profile.
      environment.systemPackages = [ pkgs.gh ];
    };
}
