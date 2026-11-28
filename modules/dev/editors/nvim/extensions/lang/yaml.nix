{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? yaml) {
      programs.nixvim = {
        plugins.lsp.servers.yamlls.enable = true;
        plugins.conform-nvim.settings.formatters_by_ft.yaml = [ "prettier" ];
        plugins.lint.lintersByFt.yaml = [ "yamllint" ];
        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [ yaml ];
      };
    };
}
