{ inputs, ... }:
{
  flake.modules.homeManager.nvim =
    { pkgs, ... }:
    let
      unicode-highlight-nvim =
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.unicode-highlight-nvim;
    in
    {
      programs.nixvim.extraPlugins = [
        unicode-highlight-nvim
      ];

      programs.nixvim.extraConfigLua = ''
        require("unicode-highlight").setup({
          highlight_ambiguous = true,
          highlight_invisible = true,
          ambiguous_hl = "UnicodeHighlightAmbiguous",
          invisible_hl = "UnicodeHighlightInvisible",
          auto_enable = true,
          filetypes = {},
          excluded_filetypes = {
            "help", "qf", "terminal", "snacks_terminal", "markdown", "text"
          },
          debounce_ms = 35,
        })

        vim.api.nvim_set_hl(0, "UnicodeHighlightAmbiguous", { bg = "#6b3a2a", underline = true })
        vim.api.nvim_set_hl(0, "UnicodeHighlightInvisible", { bg = "#6b2a2a", undercurl = true })
      '';
    };
}
