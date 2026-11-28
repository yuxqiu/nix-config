{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? json) {
      programs.nixvim = {
        plugins.lsp.servers.jsonls.enable = true;
        plugins.conform-nvim.settings.formatters_by_ft.json = [ "prettier" ];
        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [ json ];
      };
    };
}
