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

      xdg.mimeApps =
        let
          nvimForMimeTypes = lib.genAttrs [
            "application/json"
            "application/x-zerosize"
            "text/markdown"
            "text/plain"
            "text/x-c++src"
            "text/x-csrc"
            "text/x-python"
            "text/x-shellscript"
            "text/x-tex"
            "text/x-typst"
          ] (_: [ "nvim.desktop" ]);
        in
        {
          associations.added = nvimForMimeTypes;
          defaultApplications = nvimForMimeTypes;
        };
    };
}
