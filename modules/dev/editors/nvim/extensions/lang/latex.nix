{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.my.dev.languages ? latex) {
      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [ vimtex ];

        # vimtex is loaded eagerly (extraPlugins puts it in the "start"
        # pack), so its own ftplugin auto-inits on the first tex/latex/bib
        # FileType event before the lz-n "before" hook below would run.
        # These must be set here (like mapleader in ../default.nix) so
        # vimtex sees them at that first init instead of falling back to
        # its default compiler (latexmk, which isn't installed).
        globals = {
          vimtex_view_method = "sioyek";
          vimtex_compiler_method = "tectonic";
          vimtex_compiler_tectonic = {
            options = [
              "--untrusted"
              "--synctex"
              "--keep-logs"
              "--keep-intermediates"
              "-Z"
              "continue-on-errors"
            ];
          };
          tex_flavor = "latex";
          vimtex_quickfix_mode = 2;
          # Treesitter (see plugins.treesitter.grammarPackages below) owns
          # highlighting for tex/latex; vimtex's own legacy syntax highlighter
          # would otherwise clash with it and log a "Syntax highlighting is
          # controlled by Treesitter!" error on every tex buffer.
          vimtex_syntax_enabled = 0;
        };

        plugins.lz-n.plugins = [
          {
            __unkeyed-1 = "vimtex";
            ft = [
              "tex"
              "latex"
              "bib"
            ];
            after.__raw = ''
              function()
                vim.fn["vimtex#init"]()
              end
            '';
          }
        ];

        autoCmd = [
          {
            event = [ "FileType" ];
            pattern = [
              "tex"
              "latex"
            ];
            callback.__raw = ''
              function()
                vim.opt_local.wrap = true
                vim.opt_local.linebreak = true
              end
            '';
          }
          {
            event = [ "User" ];
            pattern = [ "VimtexEventInitPost" ];
            callback.__raw = ''
              function()
                vim.api.nvim_create_autocmd("BufWritePost", {
                  buffer = 0,
                  callback = function()
                    debounce("vimtex_compile", 500, function()
                      vim.cmd("VimtexStop")
                      vim.cmd("VimtexCompileSS")
                    end)
                  end,
                })
              end
            '';
          }
        ];

        plugins.lsp.servers.texlab = {
          enable = true;
          settings = {
            texlab = {
              diagnostics = {
                ignoredPatterns = [ "Unused" ];
                delay = 0.4;
              };
              # texlab's \ref/\Cref inlay hints inline the full referenced
              # figure/table caption as virtual text, which with wrap=true
              # (above) can wrap across several screen lines mid-edit and
              # make it look like the cursor jumped. Ask texlab to stop
              # computing them...
              inlayHints = {
                labelDefinitions = false;
                labelReferences = false;
              };
            };
          };
          # ...but that alone isn't enough: at buffer open, texlab can
          # compute its first inlay-hint response using default settings
          # before workspace/didChangeConfiguration settles, and Neovim only
          # re-requests hints for viewport ranges it redraws afterward -- so
          # stale hints near wherever the buffer opened can persist
          # indefinitely. Belt-and-suspenders: also disable client-side, the
          # instant texlab (specifically, not any other attached client)
          # attaches to a buffer -- scoped here via texlab's own on_attach,
          # not the generic onAttach in lsp.nix, since this is a texlab
          # quirk, not something every language server needs.
          onAttach.function = ''
            vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
          '';
        };

        plugins.conform-nvim.settings.formatters_by_ft = {
          tex = [ "latexindent" ];
          bib = [ "latexindent" ];
        };
        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [ latex ];
      };
    };
}
