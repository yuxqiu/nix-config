{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    lib.mkIf (config.dev.languages ? markdown) {
      programs.nixvim.autoCmd = [
        {
          event = [ "FileType" ];
          pattern = [ "markdown" ];
          callback.__raw = ''
            function()
              vim.opt_local.wrap = true
              vim.opt_local.linebreak = true
            end
          '';
        }
      ];

      programs.nixvim.plugins.lsp.servers.markdown_oxide.enable = true;
      programs.nixvim.plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [
        markdown
        markdown_inline
      ];
    };
}
