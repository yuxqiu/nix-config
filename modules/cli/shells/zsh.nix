{
  flake.modules.homeManager.zsh =
    {
      config,
      pkgs,
      ...
    }:
    {
      # zsh rewrites its history and Zsh-z its database by renaming a temp file
      # over the old one, so both live in a kept directory, not as kept files.
      persistence.directories = [
        {
          directory = ".local/state/zsh";
          mode = "0700";
        }
      ];
      programs.zsh = {
        enable = true;
        # Home Manager's zshrc creates this directory, which Zsh-z needs too.
        history.path = "${config.xdg.stateHome}/zsh/history";
        sessionVariables.ZSHZ_DATA = "${config.xdg.stateHome}/zsh/z";
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

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
        shellAliases = {
          sudo = "sudo ";
          open = "${pkgs.xdg-utils}/bin/xdg-open";
        };

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
        };
      };

      # oh-my-zsh clipboard plugin dependencies
      home.packages = [ pkgs.wl-clipboard ];
    };
}
