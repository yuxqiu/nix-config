{ inputs, ... }:
{
  flake.modules.homeManager.paseo =
    { pkgs, ... }:
    {
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
      # GIT_CONFIG_* (highest precedence short of `-c`). Agents never touch the
      # user's SSH agent: GitHub goes over HTTPS with the token below, and
      # commits are left unsigned for the user to re-sign on review.
      agentGitConfig = [
        [
          "url.https://github.com/.insteadOf"
          "git@github.com:"
        ]
        [
          "url.https://github.com/.insteadOf"
          "ssh://git@github.com/"
        ]
        # An empty helper resets any inherited ones.
        [
          "credential.https://github.com.helper"
          ""
        ]
        [
          "credential.https://github.com.helper"
          "!${lib.getExe pkgs.gh} auth git-credential"
        ]
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
      # nixpkgs packages paseo but ships no module; upstream's defaults to pkgs.paseo.
      imports = [ "${inputs.paseo}/nix/module.nix" ];

      services.paseo = {
        enable = true;
        group = "users";
        listenAddress = "127.0.0.1";
        # Clients reach each daemon over the tailnet (tailscale serve), not
        # through the hosted relay.
        relay.enable = false;
        # Set here because the module rewrites config.json on every start,
        # discarding changes made in the UI.
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

      # `GH_TOKEN=github_pat_...`: a fine-grained token for this host, limited
      # to the repos agents may push to. Used by git (above) and `gh`.
      sops.secrets."paseo-github.env".restartUnits = [ "paseo.service" ];
      systemd.services.paseo.serviceConfig.EnvironmentFile = config.sops.secrets."paseo-github.env".path;
    };
}
