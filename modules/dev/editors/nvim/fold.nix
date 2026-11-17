{
  flake.modules.homeManager.nvim = {
    programs.nixvim.plugins.nvim-ufo = {
      enable = true;
      settings = {
        provider_selector.__raw = ''
          function(_, _, _)
            return { "treesitter", "indent" }
          end
        '';
      };
    };

    programs.nixvim.keymaps = [
      {
        mode = "n";
        key = "zR";
        action.__raw = ''require("ufo").openAllFolds'';
        options.desc = "Open all folds";
      }
      {
        mode = "n";
        key = "zM";
        action.__raw = ''require("ufo").closeAllFolds'';
        options.desc = "Close all folds";
      }
      {
        mode = "n";
        key = "zr";
        action.__raw = ''require("ufo").openFoldsExceptKinds'';
        options.desc = "Open folds except kinds";
      }
      {
        mode = "n";
        key = "zm";
        action.__raw = ''require("ufo").closeFoldsWith'';
        options.desc = "Close folds with";
      }
      {
        mode = "n";
        key = "zp";
        action.__raw = ''
          function()
            local winid = require("ufo").peekFoldedLinesUnderCursor()
            if not winid then
              vim.lsp.buf.hover()
            end
          end
        '';
        options.desc = "Peek fold";
      }
    ];

    programs.nixvim.opts = {
      foldmethod = "expr";
      foldexpr = "v:lua.vim.treesitter.foldexpr()";
      foldcolumn = "1";
      foldnestmax = 10;
      foldenable = false;
      foldlevel = 99;
    };
  };
}
