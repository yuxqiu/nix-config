{
  flake.modules.homeManager.nvim =
    { pkgs, ... }:
    {
      programs.nixvim.plugins.treesitter = {
        enable = true;
        grammarPackages = [
          pkgs.vimPlugins.nvim-treesitter-parsers.vim
          pkgs.vimPlugins.nvim-treesitter-parsers.vimdoc
        ];
        # Folding is set up in fold.nix.
        highlight.enable = true;
        indent.enable = true;
      };
    };
}
