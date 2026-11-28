{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? nix) {
      programs.nixvim = {
        plugins.lsp.servers.nixd.enable = true;
        plugins.conform-nvim.settings.formatters_by_ft.nix = [ "nixfmt" ];
        plugins.lint.lintersByFt.nix = [
          "deadnix"
          "statix"
        ];
        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [ nix ];

        # The nix treesitter grammar computes incorrect indentation
        # (e.g. returns 0 when pressing `o`), so fall back to autoindent
        # which correctly copies the previous line's indentation.
        autoCmd = [
          {
            event = "BufEnter";
            pattern = "*.nix";
            command = "setlocal indentexpr=";
          }
        ];
      };
    };
}
