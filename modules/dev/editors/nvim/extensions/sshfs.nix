{ inputs, ... }:
{
  flake.modules.homeManager.nvim =
    { pkgs, ... }:
    let
      sshfs-nvim = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.sshfs-nvim;
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
