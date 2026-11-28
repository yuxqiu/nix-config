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
      vellum = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.vellum-nvim;
    in
    lib.mkIf (config.dev.languages ? markdown) {
      programs.nixvim.extraPlugins = [ vellum ];

      programs.nixvim.extraConfigLua = ''
        require("vellum").setup({})
        vim.keymap.set("n", "<leader>up", "<cmd>Vellum<cr>", { desc = "Toggle markdown preview" })
      '';
    };
}
