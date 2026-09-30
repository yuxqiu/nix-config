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
      # from nixpkgs-multiverse. Switch back to pkgs.mosh once it builds again.
      home.packages = [ mv.versions.mosh."1.4.0" ];
      programs.zsh.shellAliases = {
        # Immortal ssh
        sshx = ''mosh "$@" -- screen -s -/bin/bash -qRRUS "mosh-''${HOSTNAME}"'';
      };
    };
}
