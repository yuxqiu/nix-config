{
  flake.modules.homeManager.nvim = {
    programs.nixvim = {
      plugins.mini-bufremove.enable = true;
      plugins.bufferline = {
        enable = true;
        settings = {
          options = {
            diagnostics = "nvim_lsp";
            show_buffer_close_icons = true;
            show_close_icon = false;
            separator_style = "thin";
            close_command.__raw = ''
              function(bufnr)
                require("mini.bufremove").delete(bufnr)
              end
            '';
            right_mouse_command.__raw = ''
              function(bufnr)
                require("mini.bufremove").delete(bufnr)
              end
            '';
            offsets = [
              {
                filetype = "neo-tree";
                text = "File Explorer";
                padding = 1;
              }
              {
                filetype = "snacks_terminal";
                text = "Terminal";
                padding = 1;
              }
            ];
          };
          highlights.__raw = ''require("catppuccin.special.bufferline").get_theme()'';
        };
      };

      # Quickfix buffers are listed by default, so bufferline shows every
      # quickfix window (vimtex errors, :grep, LSP references) as an
      # unnamed tab. Unlist them; the split itself is unaffected.
      autoCmd = [
        {
          event = [ "FileType" ];
          pattern = [ "qf" ];
          callback.__raw = ''
            function()
              vim.bo.buflisted = false
            end
          '';
        }
      ];

      keymaps = [
        {
          mode = "n";
          key = "<C-Tab>";
          action = "<cmd>BufferLineCycleNext<CR>";
          options.desc = "Next buffer";
        }
        {
          mode = "n";
          key = "<C-S-Tab>";
          action = "<cmd>BufferLineCyclePrev<CR>";
          options.desc = "Prev buffer";
        }
        {
          mode = "n";
          key = "<C-w>";
          action.__raw = ''function() require("mini.bufremove").delete() end'';
          options.desc = "Close buffer";
        }
      ];
    };
  };
}
