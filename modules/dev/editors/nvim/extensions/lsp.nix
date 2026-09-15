{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      ...
    }:
    {
      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [ fastaction-nvim ];

        extraConfigLua = ''
          require("fastaction").setup({
            popup = {
              border = "rounded",
            },
          })

          -- LSP logging off by default; toggle with glL when investigating.
          vim.lsp.log.set_level("off")

          -- Let <Esc> close the hover float (built-in only maps "q").
          do
            local orig_open_floating_preview = vim.lsp.util.open_floating_preview
            vim.lsp.util.open_floating_preview = function(contents, syntax, opts)
              local bufnr, winnr = orig_open_floating_preview(contents, syntax, opts)
              if opts and opts.focus_id == "textDocument/hover" then
                vim.keymap.set("n", "<Esc>", "<cmd>bdelete<CR>", { buffer = bufnr, silent = true, nowait = true })
              end
              return bufnr, winnr
            end
          end

          vim.lsp.handlers["workspace/executeCommand"] = function(err, result, ctx, config)
            if err then
              local lines = vim.split(err.message or tostring(err), "\n")
              _G.open_result_split("Code Lens Error", lines)
              return
            end
            if not result or vim.tbl_isempty(result) then
              return
            end
            local lines = vim.split(vim.inspect(result), "\n")
            _G.open_result_split(nil, lines)
          end
        '';

        keymaps = [
          {
            mode = "n";
            key = "<C-.>";
            action.__raw = ''require("fastaction").code_action'';
            options.desc = "Code Action";
          }
          {
            mode = "n";
            key = "gla";
            action.__raw = ''require("fastaction").code_action'';
            options.desc = "Code Action";
          }
          {
            mode = "n";
            key = "glL";
            action.__raw = ''
              function()
                local off = vim.log.levels.OFF
                if vim.lsp.log.get_level() == off then
                  vim.lsp.log.set_level(vim.log.levels.DEBUG)
                  vim.notify("LSP log level: debug", vim.log.levels.INFO)
                else
                  vim.lsp.log.set_level(off)
                  vim.notify("LSP log level: off", vim.log.levels.INFO)
                end
              end
            '';
            options.desc = "Toggle LSP log level (off/debug)";
          }
          {
            mode = "n";
            key = "glS";
            action = "<cmd>lsp restart<CR>";
            options.desc = "Restart LSP server";
          }
        ];

        plugins.lsp = {
          enable = true;
          inlayHints = true;

          capabilities = ''
            local cmp_caps = require("cmp_nvim_lsp").default_capabilities()
            for k, v in pairs(cmp_caps) do capabilities[k] = v end
            capabilities.textDocument.completion.completionItem.snippetSupport = true
            capabilities.textDocument.foldingRange = { dynamicRegistration = false, lineFoldingOnly = true }
          '';

          onAttach = ''
            if client.server_capabilities.foldingRangeProvider then
              local win = vim.api.nvim_get_current_win()
              vim.wo[win].foldexpr = "v:lua.vim.lsp.foldexpr()"
            end
            if client.server_capabilities.codeLensProvider then
              vim.lsp.codelens.enable(true, { bufnr = bufnr })
            end
          '';

          keymaps = {
            silent = true;
            lspBuf = {
              gld = "definition";
              gli = "implementation";
              gly = "type_definition";
              glD = "declaration";
              glh = "hover";
              gls = "signature_help";
              glR = "rename";
            };
            diagnostic = {
              "<C-j>" = "goto_next";
              "<C-k>" = "goto_prev";
            };
            extra = [
              {
                key = "glr";
                action.__raw = "require('telescope.builtin').lsp_references";
                options.desc = "References";
              }
              {
                key = "glx";
                action = "<cmd>lua vim.lsp.codelens.run()<CR>";
                options.desc = "Run Codelens";
              }
              {
                key = "glX";
                action = "<cmd>lua vim.lsp.codelens.refresh()<CR>";
                options.desc = "Refresh Codelens";
              }
              {
                key = "<2-LeftMouse>";
                action.__raw = ''
                  function()
                    local lenses = vim.lsp.codelens.get({ bufnr = 0 })
                    if #lenses > 0 then
                      vim.lsp.codelens.run()
                    else
                      vim.fn.execute("normal! \\<2-LeftMouse>")
                    end
                  end
                '';
                options.desc = "Click code lens or default double-click";
              }
            ];
          };
        };

        diagnostic.settings = {
          virtual_text = false;
          virtual_lines.current_line = true;
          severity_sort = true;
          underline = true;
          signs = true;
          float = {
            source = "always";
          };
        };
      };
    };
}
