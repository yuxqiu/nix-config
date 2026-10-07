{
  flake.modules.homeManager.nvim =
    { pkgs, ... }:
    {
      # resession serializes only windows showing real files (no floats, no
      # nofile/quickfix scratch windows) and only the options it's told to,
      # unlike :mksession which also freezes fold/global options.
      programs.nixvim.extraPlugins = [ pkgs.vimPlugins.resession-nvim ];

      programs.nixvim.extraConfigLua = ''
        do
          local resession = require("resession")
          resession.setup({})

          -- Per-directory sessions, following the README recipe. Only nvim
          -- started with no file args (and not reading stdin) loads and saves.
          local dir = "dirsession"
          local autosave = false

          -- A tab whose windows were all filtered out (e.g. only lean stderr)
          -- is restored as an empty tab; drop those.
          resession.add_hook("post_load", function()
            for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
              local has_file = vim.iter(vim.api.nvim_tabpage_list_wins(tab)):any(function(win)
                return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) ~= ""
              end)
              if not has_file and #vim.api.nvim_list_tabpages() > 1 then
                vim.cmd.tabclose(vim.api.nvim_tabpage_get_number(tab))
              end
            end
          end)

          vim.api.nvim_create_autocmd("StdinReadPre", {
            callback = function() vim.g.using_stdin = true end,
          })
          vim.api.nvim_create_autocmd("VimEnter", {
            nested = true,
            callback = function()
              if vim.fn.argc(-1) == 0 and not vim.g.using_stdin then
                autosave = true
                resession.load(vim.fn.getcwd(), { dir = dir, silence_errors = true })
              end
            end,
          })
          vim.api.nvim_create_autocmd("VimLeavePre", {
            callback = function()
              if not autosave then
                return
              end
              -- No window shows a file: forget the session instead of keeping
              -- the previous layout.
              local has_file = vim.iter(vim.api.nvim_list_wins()):any(function(win)
                return resession.default_buf_filter(vim.api.nvim_win_get_buf(win))
              end)
              if not has_file then
                pcall(resession.delete, vim.fn.getcwd(), { dir = dir, notify = false })
                return
              end
              -- The built-in quickfix extension would restore an open quickfix
              -- window (e.g. vimtex errors); close it so it isn't saved.
              vim.cmd.cclose()
              resession.save(vim.fn.getcwd(), { dir = dir, notify = false })
            end,
          })

          vim.keymap.set("n", "<leader>qs", function()
            resession.load(vim.fn.getcwd(), { dir = dir })
          end, { desc = "Restore session" })
          vim.keymap.set("n", "<leader>qS", function()
            resession.load(nil, { dir = dir })
          end, { desc = "Select session" })
          vim.keymap.set("n", "<leader>ql", function()
            local last = resession.list({ dir = dir })[1]
            if last then resession.load(last, { dir = dir }) end
          end, { desc = "Restore last session" })
          vim.keymap.set("n", "<leader>qd", function()
            autosave = false
          end, { desc = "Stop session saving" })
        end
      '';
    };
}
