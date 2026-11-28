{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? typst) {
      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [ typst-vim ];

        plugins.lz-n.plugins = [
          {
            __unkeyed-1 = "typst.vim";
            ft = "typst";
            before.__raw = ''
              function()
                vim.g.typst_auto_compile = 0
                vim.g.typst_pdf_viewer = "sioyek"
              end
            '';
          }
        ];

        autoCmd = [
          {
            event = [ "FileType" ];
            pattern = [ "typst" ];
            callback.__raw = ''
              function()
                vim.opt_local.wrap = true
                vim.opt_local.linebreak = true
              end
            '';
          }
        ];

        plugins.lsp.servers.tinymist = {
          enable = true;
          settings = {
            exportPdf = "onSave";
            formatterMode = "typstyle";
          };
        };

        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [ typst ];
      };
    };
}
