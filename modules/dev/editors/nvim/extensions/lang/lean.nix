{
  flake.modules.homeManager.nvim =
    {
      config,
      lib,
      ...
    }:
    lib.mkIf (config.my.dev.languages ? lean) {
      programs.nixvim.plugins.lean = {
        enable = true;
        settings = {
          mappings = true;
          lsp.enable = true;
        };
      };
      # elan (via toolchain) already provides lean/lake on PATH, respecting
      # each project's lean-toolchain pin. Don't pull in nixvim's own
      # lean4 package as an extra dependency.
      programs.nixvim.dependencies.lean.enable = false;

      # Some glyphs in Lean's abbreviation table also have an emoji form
      # (e.g. ✝, which marks inaccessible names in goals), and terminals may
      # draw them as color emoji. Redraw each with U+FE0E (VS15) to request
      # text presentation. Display-only: buffer text and yanks are unchanged.
      # Scoped to Lean buffers, the infoview, and LSP floats (hover,
      # diagnostics) opened from a Lean buffer.
      programs.nixvim.extraConfigLua = ''
        do
          local chars = { "‼", "⁉", "◾", "☢", "☣", "⚠", "✂", "✉", "✝", "✴" }
          local fts = { lean = true, leaninfo = true }
          local ns = vim.api.nvim_create_namespace("lean_text_presentation")
          vim.api.nvim_set_decoration_provider(ns, {
            on_win = function(_, win, buf)
              if fts[vim.bo[buf].filetype] then return true end
              local src = vim.w[win].lsp_floating_bufnr
              return src ~= nil and vim.api.nvim_buf_is_valid(src) and vim.bo[src].filetype == "lean"
            end,
            on_line = function(_, _, buf, row)
              local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
              for _, c in ipairs(chars) do
                local s, e = line:find(c, 1, true)
                while s do
                  -- Leave it alone if a variation selector (U+FE0E/F) follows.
                  if not line:sub(e + 1, e + 3):match("^\239\184[\142\143]") then
                    vim.api.nvim_buf_set_extmark(buf, ns, row, s - 1, {
                      virt_text = { { c .. "\u{FE0E}" } },
                      virt_text_pos = "overlay",
                      hl_mode = "combine",
                      ephemeral = true,
                    })
                  end
                  s, e = line:find(c, e + 1, true)
                end
              end
            end,
          })
        end
      '';
    };
}
