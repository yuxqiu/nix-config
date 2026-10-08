{
  flake.modules.homeManager.nvim =
    { pkgs, lib, ... }:
    {
      programs.nixvim = {
        extraPackages = with pkgs; [
          imagemagick
          ghostscript
          mermaid-cli
        ];

        plugins.snacks = {
          enable = true;
          settings = {
            bigfile = {
              enabled = true;
            };
            dashboard = {
              enabled = true;
              sections = [
                { section = "header"; }
                {
                  section = "keys";
                  gap = 1;
                  padding = 1;
                }
                {
                  section = "recent_files";
                  icon = " ";
                  title = "Recent Files";
                  cwd = true;
                  limit = 5;
                  padding = 1;
                }
                {
                  section = "projects";
                  icon = " ";
                  title = "Projects";
                  limit = 3;
                  padding = 1;
                }
              ];
              preset.keys = [
                {
                  icon = " ";
                  key = "f";
                  desc = "Find File";
                  action = ":lua Snacks.dashboard.pick('files')";
                }
                {
                  icon = " ";
                  key = "n";
                  desc = "New File";
                  action = ":ene | startinsert";
                }
                {
                  icon = " ";
                  key = "r";
                  desc = "Recent Files";
                  action = ":lua Snacks.dashboard.pick('oldfiles')";
                }
                {
                  icon = " ";
                  key = "g";
                  desc = "Find Text";
                  action = ":lua Snacks.dashboard.pick('live_grep')";
                }
              ];
            };
            git = {
              enabled = true;
            };
            gitbrowse = {
              enabled = true;
            };
            image = {
              enabled = true;
              # disable in-editor markdown math preview
              math = {
                enabled = false;
              };
            };
            indent = {
              enabled = true;
              char = "▏";
              scope = {
                enabled = true;
                show_start = false;
                show_end = false;
              };
            };
            input = {
              enabled = true;
            };
            notifier = {
              enabled = false;
            };
            quickfile = {
              enabled = true;
            };
            scope = {
              enabled = true;
            };
            statuscolumn = {
              enabled = true;
            };
            terminal = {
              enabled = true;
              interactive = false;
              # start_insert is handled by on_win below to preserve the mode
              # across toggle off/on cycles instead of always forcing insert.
              start_insert = false;
              auto_close = true;
              win = {
                enter = true;
                wo = {
                  winbar = "";
                };
                on_win.__raw = ''
                  function(self)
                    if vim.api.nvim_get_current_buf() ~= self.buf then return end
                    -- First open: no saved mode → insert. Toggle-on: restore
                    -- the mode saved by the WinLeave autocmd below.
                    if vim.b[self.buf]._snacks_term_mode == "n" then
                      vim.cmd.stopinsert()
                    else
                      vim.cmd.startinsert()
                    end
                  end
                '';
                keys = {
                  term_normal = {
                    __raw = ''
                      {
                        "<esc>",
                        function()
                          return "<C-\\><C-n>"
                        end,
                        mode = "t",
                        expr = true,
                        desc = "Exit terminal mode",
                      }
                    '';
                  };
                };
              };
            };
            toggle = {
              enabled = true;
            };
            words = {
              enabled = true;
            };
            zen = {
              enabled = true;
            };
          };
        };

        extraConfigLua = lib.mkAfter ''
          vim.api.nvim_set_hl(0, "SnacksNormal", { link = "Normal" })
          vim.api.nvim_set_hl(0, "SnacksNormalNC", { link = "Normal" })

          -- Save terminal mode before the window is hidden so on_win can
          -- restore it on toggle-on instead of always forcing insert mode.
          vim.api.nvim_create_autocmd("WinLeave", {
            callback = function(args)
              if vim.bo[args.buf].buftype == "terminal" then
                vim.b[args.buf]._snacks_term_mode = vim.fn.mode()
              end
            end,
          })

          local last_term_id
          vim.api.nvim_create_autocmd("BufEnter", {
            callback = function(args)
              if vim.bo[args.buf].buftype == "terminal" then
                local st = vim.b[args.buf].snacks_terminal
                if st and st.id then
                  last_term_id = st.id
                end
              end
            end,
          })

          local function toggle_terminal()
            local buf = vim.api.nvim_get_current_buf()
            if vim.bo[buf].buftype == "terminal" then
              local st = vim.b[buf].snacks_terminal
              if st and st.id then
                Snacks.terminal.toggle(nil, { count = st.id })
                return
              end
            end
            if last_term_id then
              Snacks.terminal.toggle(nil, { count = last_term_id })
              return
            end
            Snacks.terminal.toggle()
          end
          vim.keymap.set("t", "<C-`>", toggle_terminal, { desc = "Toggle current terminal" })
          vim.keymap.set("n", "<C-`>", toggle_terminal, { desc = "Toggle current terminal" })

          local function term_picker()
            local terms = Snacks.terminal.list()
            if #terms == 0 then
              vim.notify("No terminals", vim.log.levels.INFO)
              return
            end
            local pickers = require("telescope.pickers")
            local finders = require("telescope.finders")
            local conf = require("telescope.config").values
            local actions = require("telescope.actions")
            local action_state = require("telescope.actions.state")
            local entries = {}
            for _, term in ipairs(terms) do
              local name = vim.b[term.buf].term_title or "shell"
              local id = vim.b[term.buf].snacks_terminal and vim.b[term.buf].snacks_terminal.id or "?"
              table.insert(entries, { term = term, display = "#" .. id .. " " .. name })
            end
            pickers.new({}, {
              prompt_title = "Terminals",
              finder = finders.new_table({
                results = entries,
                entry_maker = function(entry)
                  return { value = entry, display = entry.display, ordinal = entry.display }
                end,
              }),
              sorter = conf.generic_sorter({}),
              attach_mappings = function(bufnr, _)
                actions.select_default:replace(function()
                  local selection = action_state.get_selected_entry()
                  actions.close(bufnr)
                  if selection then selection.value.term:focus() end
                end)
                return true
              end,
            }):find()
          end
          vim.keymap.set("n", "<leader>tt", term_picker, { desc = "Terminal picker" })
        '';

        keymaps = [
          {
            mode = "n";
            key = "<leader>uz";
            action.__raw = "function() Snacks.zen.zen() end";
            options.desc = "Toggle Zen mode";
          }
          {
            mode = "n";
            key = "<leader>gb";
            action.__raw = "function() Snacks.gitbrowse.open() end";
            options.desc = "Git browse";
          }
          {
            mode = "n";
            key = "<leader>gl";
            action.__raw = "function() Snacks.git.blame_line() end";
            options.desc = "Git blame line";
          }
          {
            mode = "n";
            key = "]]";
            action.__raw = "function() Snacks.words.jump(vim.v.count1) end";
            options.desc = "Next Reference";
          }
          {
            mode = "n";
            key = "[[";
            action.__raw = "function() Snacks.words.jump(-vim.v.count1) end";
            options.desc = "Prev Reference";
          }
        ]
        ++ (lib.genList (i: {
          mode = "n";
          key = "<leader>t${toString (i + 1)}";
          action.__raw = "function() Snacks.terminal.toggle(nil, { count = ${toString (i + 1)} }) end";
          options.desc = "Toggle terminal ${toString (i + 1)}";
        }) 9);
      };
    };
}
