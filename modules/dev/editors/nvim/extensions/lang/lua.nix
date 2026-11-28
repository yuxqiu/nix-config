{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? lua) {
      programs.nixvim = {
        plugins.lsp.servers.lua_ls.enable = true;
        plugins.conform-nvim.settings.formatters_by_ft.lua = [ "stylua" ];
        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [ lua ];
      };
    };
}
