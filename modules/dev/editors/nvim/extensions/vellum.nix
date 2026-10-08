{ inputs, ... }:
{
  flake.modules.homeManager.nvim =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      vellum = pkgs.callPackage (inputs.self + /packages/vellum-nvim.nix) { };
    in
    lib.mkIf (config.my.dev.languages ? markdown) {
      programs.nixvim.extraPlugins = [ vellum ];

      programs.nixvim.extraConfigLua = ''
        require("vellum").setup({})
        vim.keymap.set("n", "<leader>up", "<cmd>Vellum<cr>", { desc = "Toggle markdown preview" })
      '';
    };
}
