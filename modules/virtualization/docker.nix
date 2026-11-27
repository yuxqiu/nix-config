{
  flake.modules.homeManager.docker =
    { pkgs, ... }:
    {
      persistence.directories = [
        {
          directory = ".local/share/docker";
          mode = "0710";
        }
      ];
      home.packages = with pkgs; [ lazydocker ];

      programs.zsh = {
        shellAliases = {
          # Docker
          dockps = ''docker ps --format "{{.ID}} {{.Names}}"'';
          docklsc = "docker ps -a";
          dockrmc = "docker rm";
          docklsi = "docker images -a";
          dockrmi = "docker rmi";

          # Docker Compose
          dcbuild = "docker-compose build";
          dcup = "docker-compose up";
          dcdown = "docker-compose down";
        };

        siteFunctions = {
          docksh = ''
            docker exec -it $1 /bin/bash
          '';
        };
      };
    };

  # Rootless: membership in the docker group of a root daemon is root-equivalent.
  flake.modules.nixos.docker =
    { lib, ... }:
    {
      virtualisation.docker.rootless = {
        enable = true;
        setSocketVariable = true;
      };
      # The user unit is wanted by every user manager; nixpkgs only excludes
      # root, so system users with a manager (the greeter) kept failing to
      # start it.
      systemd.user.services.docker.unitConfig.ConditionUser = lib.mkForce "!@system";
    };
}
