{
  config.flake.modules.homeManager.ssh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Only known hosts are kept. ~/.ssh itself is not: a config or a file
      # in config.d left there by any program running as the user would make
      # every later ssh run its commands (ProxyCommand, Match exec), so they
      # last only until the next reboot. Keys come from the agent.
      persistence.directories = [
        {
          directory = ".local/state/ssh";
          mode = "0700";
        }
      ];
      programs.ssh = {
        enable = true;

        settings = lib.mapAttrs (_: hostName: { HostName = hostName; }) config.tailnet // {
          # base config
          "*" = {
            forwardAgent = false;
            addKeysToAgent = "no";
            compression = false;
            serverAliveInterval = 300;
            serverAliveCountMax = 3;
            hashKnownHosts = true;
            userKnownHostsFile = "~/.local/state/ssh/known_hosts";
          };
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
