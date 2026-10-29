{ inputs, ... }:
{
  flake.modules.homeManager.nvim =
    { pkgs, ... }:
    let
      sshfs-nvim = pkgs.callPackage (inputs.self + /packages/sshfs-nvim.nix) { };
    in
    {
      programs.nixvim.extraPlugins = [
        sshfs-nvim
      ];

      programs.nixvim.extraPackages = [ pkgs.sshfs ];

      programs.nixvim.extraConfigLua = ''
        require("sshfs").setup({
          lead_prefix = "<leader>R",
        })
      '';
    };
}
