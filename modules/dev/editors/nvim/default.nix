{ inputs, ... }:
{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      lib,
      ...
    }:
    {
      imports = [ inputs.nixvim.homeModules.nixvim ];

      programs.nixvim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
        defaultEditor = true;
        wrapRc = true;
        impureRtp = false;

        nixpkgs.pkgs = pkgs;

        luaLoader.enable = true;
        performance.byteCompileLua.enable = true;

        withRuby = false;

        # Set leader key before lz.n.load runs (in extraConfigLuaPre),
        # so that <leader> in lazy-loaded keymaps expands to <space>.
        extraConfigLuaPre = lib.mkBefore ''
          vim.g.mapleader = " "
          vim.keymap.set("n", "<leader>", "<Nop>")
        '';

        plugins.lz-n.enable = true;

        colorschemes.catppuccin = {
          enable = true;
          settings.flavour = "mocha";
        };

        editorconfig.enable = true;
        plugins.todo-comments.enable = true;
        plugins.web-devicons.enable = true;

        extraPackages = with pkgs; [
          ripgrep
          fd
        ];
      };

      stylix.targets.nixvim.enable = false;

      xdg.mimeApps = {
        associations.added = {
          "application/json" = [ "nvim.desktop" ];
          "application/x-zerosize" = [ "nvim.desktop" ];
          "text/markdown" = [ "nvim.desktop" ];
          "text/plain" = [ "nvim.desktop" ];
          "text/x-c++src" = [ "nvim.desktop" ];
          "text/x-csrc" = [ "nvim.desktop" ];
          "text/x-python" = [ "nvim.desktop" ];
          "text/x-shellscript" = [ "nvim.desktop" ];
          "text/x-tex" = [ "nvim.desktop" ];
          "text/x-typst" = [ "nvim.desktop" ];
        };
        defaultApplications = {
          "application/json" = [ "nvim.desktop" ];
          "application/x-zerosize" = [ "nvim.desktop" ];
          "text/markdown" = [ "nvim.desktop" ];
          "text/plain" = [ "nvim.desktop" ];
          "text/x-c++src" = [ "nvim.desktop" ];
          "text/x-csrc" = [ "nvim.desktop" ];
          "text/x-python" = [ "nvim.desktop" ];
          "text/x-shellscript" = [ "nvim.desktop" ];
          "text/x-tex" = [ "nvim.desktop" ];
          "text/x-typst" = [ "nvim.desktop" ];
        };
      };
    };
}
