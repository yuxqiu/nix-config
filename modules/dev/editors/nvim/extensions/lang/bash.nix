{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? bash) {
      programs.nixvim = {
        plugins.lsp.servers.bashls.enable = true;
        plugins.conform-nvim.settings.formatters_by_ft = {
          bash = [ "shfmt" ];
          sh = [ "shfmt" ];
        };
        plugins.lint.lintersByFt = {
          bash = [ "shellcheck" ];
          sh = [ "shellcheck" ];
        };
        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [ bash ];
      };
    };
}
