{
  config.flake.modules.homeManager.ssh =
    { pkgs, ... }:
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

      home.packages = [ pkgs.mosh ];
      programs.zsh.shellAliases = {
        # Immortal ssh
        sshx = ''mosh "$@" -- screen -s -/bin/bash -qRRUS "mosh-''${HOSTNAME}"'';
      };
    };
}
