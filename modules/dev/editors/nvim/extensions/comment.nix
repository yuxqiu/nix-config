{
  flake.modules.homeManager.nvim = {
    programs.nixvim = {
      plugins.ts-context-commentstring = {
        enable = true;
        settings.enable_autocmd = false;
      };

      plugins.comment = {
        enable = true;
        settings = {
          padding = true;
          sticky = true;
          # ts_context_commentstring only covers filetypes/injections in its own
          # table; Comment.nvim's own fallback (Comment.ft.calculate) crashes
          # when a filetype has no treesitter parser installed at all (e.g.
          # lean, which relies on legacy syntax highlighting), since
          # vim.treesitter.get_parser() returns nil instead of erroring. Own
          # the fallback chain here instead of delegating into that: ts
          # context -> Comment.nvim's static per-filetype table -> plain
          # 'commentstring'.
          pre_hook.__raw = ''
            function(ctx)
              local cs = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook()(ctx)
              if cs then
                return cs
              end
              return require('Comment.ft').get(vim.bo.filetype, ctx.ctype) or vim.bo.commentstring
            end
          '';
          opleader.line = "gc";
        };
      };

      keymaps = [
        {
          key = "<C-/>";
          mode = "n";
          action = "<Plug>(comment_toggle_linewise_current)";
          options.desc = "Toggle comment";
        }
        {
          key = "<C-/>";
          mode = "v";
          action = "<Plug>(comment_toggle_linewise_visual)";
          options.desc = "Toggle comment";
        }
        {
          key = "<C-/>";
          mode = "i";
          action = "<Esc><Plug>(comment_toggle_linewise_current)A";
          options.desc = "Toggle comment";
        }
      ];
    };
  };
}
