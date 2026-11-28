{
  flake.modules.homeManager.nvim =
    { pkgs, ... }:
    {
      programs.nixvim.plugins.treesitter = {
        enable = true;
        # Setting this replaces nixvim's default of every grammar, so each
        # lang/<lang>.nix adds the grammars for its filetypes.
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
