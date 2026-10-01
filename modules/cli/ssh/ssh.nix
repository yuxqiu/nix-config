{
  config.flake.modules.homeManager.ssh =
    { mv, ... }:
    {
      programs.ssh = {
        enable = true;

        # base config
        settings."*" = {
          forwardAgent = false;
          addKeysToAgent = "no";
          compression = false;
          serverAliveInterval = 300;
          serverAliveCountMax = 3;
          hashKnownHosts = true;
          userKnownHostsFile = "~/.ssh/known_hosts";
        };

        includes = [ "config.d/*" ];
        enableDefaultConfig = false;
      };

      # TEMP: nixpkgs mosh fails to build upstream; use the cached 1.4.0
      # pinned to nixpkgs 7a0f122f5090 via multiverse. Switch back to pkgs.mosh once it builds again.
      home.packages = [ (mv.at "7a0f122f5090").mosh ];
      programs.zsh.shellAliases = {
        # Immortal ssh
        sshx = ''mosh "$@" -- screen -s -/bin/bash -qRRUS "mosh-''${HOSTNAME}"'';
      };
    };
}
