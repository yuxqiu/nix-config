{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? c) {
      programs.nixvim = {
        plugins.lsp.servers.clangd.enable = true;
        plugins.conform-nvim.settings.formatters_by_ft = {
          c = [ "clang_format" ];
          cpp = [ "clang_format" ];
        };
        plugins.lint.lintersByFt = {
          c = [ "clangtidy" ];
          cpp = [ "clangtidy" ];
        };
        plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [
          c
          cpp
        ];
      };
    };
}
