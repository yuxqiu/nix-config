{
  flake.modules.homeManager.nvim =
    { pkgs, ... }:
    {
      programs.nixvim = {
        plugins.telescope = {
          enable = true;
          lazyLoad.settings = {
            cmd = [ "Telescope" ];
            keys = [
              {
                __unkeyed-1 = "<C-p>";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").find_files()
                  end
                '';
                desc = "Find files";
              }
              {
                __unkeyed-1 = "<leader>fb";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").buffers()
                  end
                '';
                desc = "Find buffers";
              }
              {
                __unkeyed-1 = "<leader>fh";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").help_tags()
                  end
                '';
                desc = "Help tags";
              }
              {
                __unkeyed-1 = "<leader>fo";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").oldfiles()
                  end
                '';
                desc = "Recent files";
              }
              {
                __unkeyed-1 = "<leader>fc";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").commands()
                  end
                '';
                desc = "Commands";
              }
              {
                __unkeyed-1 = "<leader>fr";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").resume()
                  end
                '';
                desc = "Resume last picker";
              }
              {
                __unkeyed-1 = "<C-S-F>";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").live_grep()
                  end
                '';
                desc = "Search in project";
              }
              {
                __unkeyed-1 = "<leader>fk";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").keymaps()
                  end
                '';
                desc = "Search keymaps";
              }
              {
                __unkeyed-1 = "<leader>ff";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").find_files()
                  end
                '';
                desc = "Find files";
              }
              {
                __unkeyed-1 = "<leader>fs";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").builtin()
                  end
                '';
                desc = "Telescope pickers";
              }
              {
                __unkeyed-1 = "<leader>fw";
                mode = [
                  "n"
                  "v"
                ];
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").grep_string()
                  end
                '';
                desc = "Search word under cursor";
              }
              {
                __unkeyed-1 = "<leader>fg";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").live_grep()
                  end
                '';
                desc = "Live grep";
              }
              {
                __unkeyed-1 = "<leader>fd";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").diagnostics()
                  end
                '';
                desc = "Search diagnostics";
              }
              {
                __unkeyed-1 = "<leader>fO";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").lsp_document_symbols()
                  end
                '';
                desc = "Search document symbols";
              }
              {
                __unkeyed-1 = "<leader>fW";
                __unkeyed-2.__raw = ''
                  function()
                    require("telescope.builtin").lsp_workspace_symbols()
                  end
                '';
                desc = "Search workspace symbols";
              }
            ];
          };
          settings = {
            defaults = {
              vimgrep_arguments = [
                "${pkgs.ripgrep}/bin/rg"
                "-L"
                "--color=never"
                "--no-heading"
                "--with-filename"
                "--line-number"
                "--column"
                "--smart-case"
                "--fixed-strings"
              ];
              file_ignore_patterns = [
                "%.git/"
                "node_modules"
              ];
            };
            pickers = {
              find_files.hidden = true;
            };
          };
        };

        plugins.telescope.extensions.fzf-native.enable = true;
        plugins.telescope.extensions.undo.enable = true;

        keymaps = [
          {
            key = "<C-f>";
            action = "/";
            options.desc = "Search in file";
          }
          {
            mode = "n";
            key = "<leader>ut";
            action = "<cmd>Telescope undo<CR>";
            options.desc = "Undo history";
          }
        ];

        extraConfigLua = ''
          -- Project tracking: record directories opened with nvim (no file args)
          local _project_file = vim.fn.stdpath("data") .. "/nvim-projects"
          local function _project_lines()
            local f = io.open(_project_file, "r")
            if not f then return function() end end
            return f:lines()
          end
          local function _project_add(dir)
            if not dir or dir == "" or not vim.fn.isdirectory(dir) then return end
            dir = vim.fn.fnamemodify(dir, ":p:h")
            if dir == "/tmp" then return end
            local seen = {}
            for line in _project_lines() do
              seen[line] = true
            end
            if seen[dir] then return end
            local f = io.open(_project_file, "a")
            if f then
              f:write(dir .. "\n")
              f:close()
            end
          end
          if vim.fn.argc(-1) == 0 then
            _project_add(vim.fn.getcwd())
          end

          vim.keymap.set("n", "<C-o>", function()
            require('lz.n').trigger_load('telescope.nvim')
            local pickers = require("telescope.pickers")
            local finders = require("telescope.finders")
            local conf = require("telescope.config").values
            local actions = require("telescope.actions")
            local action_state = require("telescope.actions.state")
            local dirs = {}
            local seen = {}
            for line in _project_lines() do
              if line ~= "" and not seen[line] then
                seen[line] = true
                dirs[#dirs + 1] = line
              end
            end
            pickers.new({}, {
              prompt_title = "Recent Projects",
              finder = finders.new_table({ results = dirs }),
              sorter = conf.generic_sorter({}),
              attach_mappings = function(bufnr, map)
                actions.select_default:replace(function()
                  local dir = action_state.get_selected_entry()[1]
                  actions.close(bufnr)
                  vim.fn.chdir(dir)
                  require("neo-tree.command").execute({ source_name = "filesystem", action = "focus", dir = dir })
                  require("telescope.builtin").find_files({ cwd = dir })
                end)
                return true
              end,
            }):find()
          end, { desc = "Recent projects" })
        '';
      };
    };
}
