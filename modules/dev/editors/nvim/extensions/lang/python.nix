{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? python) {
      programs.nixvim = {
        plugins.lsp.servers.basedpyright.enable = true;
        plugins.conform-nvim.settings.formatters_by_ft.python = [ "ruff_format" ];
        plugins.lint.lintersByFt.python = [ "ruff" ];
        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [ python ];
      };
    };
}
