{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? css) {
      programs.nixvim = {
        plugins.lsp.servers.cssls.enable = true;
        plugins.conform-nvim.settings.formatters_by_ft = {
          css = [ "prettier" ];
          scss = [ "prettier" ];
        };
        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [
          css
          scss
        ];
      };
    };
}
