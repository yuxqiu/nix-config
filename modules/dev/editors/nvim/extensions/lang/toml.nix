{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? toml) {
      programs.nixvim = {
        plugins.lsp.servers.taplo.enable = true;
        plugins.conform-nvim.settings.formatters_by_ft.toml = [ "taplo" ];
        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [ toml ];
      };
    };
}
