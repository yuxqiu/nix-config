{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? go) {
      programs.nixvim = {
        plugins.lsp.servers.gopls.enable = true;
        plugins.conform-nvim.settings.formatters_by_ft.go = [ "gofmt" ];
        plugins.lint.lintersByFt.go = [ "golangcilint" ];
        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [ go ];
      };
    };
}
