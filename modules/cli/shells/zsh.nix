{
  flake.modules.homeManager.zsh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.zsh = {
        enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        initContent = ''
          fpath+=("${config.home.profileDirectory}/share/zsh/site-functions" /run/current-system/sw/share/zsh/site-functions /run/current-system/sw/share/zsh/vendor-completions)
        '';

        # Enable Oh My Zsh
        oh-my-zsh = {
          enable = true;
          plugins = [
            "git"
            "colored-man-pages"
            "z"
            "jj"
          ];
          theme = "robbyrussell";
        };

        # Aliases
        shellAliases = lib.mkMerge [
          { sudo = "sudo "; }
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux { open = "${pkgs.xdg-utils}/bin/xdg-open"; })
        ];

        siteFunctions = {
          gc-pip = ''
            for pkg in $(python3 -m pip list --not-required --format=freeze 2>/dev/null | cut -d= -f1 | tail -n +3); do
                echo -n "Removing $pkg ... " ;
                python3 -m pip uninstall -y "$pkg" >/dev/null 2>&1 && echo "removed" || echo "skipped (protected or undeletable)";
            done
          '';
          gc-kondo = "${pkgs.kondo}/bin/kondo";
          gc-nix = "nix-collect-garbage -d";
          gc-hm = ''
            home-manager expire-generations now
            gc-nix
          '';
          gc-nixos = ''
            sudo nix-env --delete-generations old -p /nix/var/nix/profiles/system
            gc-nix
          '';
          gc-cache = "${pkgs.bleachbit}/bin/bleachbit";
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          jdks = "/usr/libexec/java_home -V";

          jdk = ''
            version=$1
            export JAVA_HOME=$(/usr/libexec/java_home -v"$version");
            java -version
          '';
        };
      };

      # oh-my-zsh clipboard plugin dependencies (Linux only)
      home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.wl-clipboard ];
    };
}
