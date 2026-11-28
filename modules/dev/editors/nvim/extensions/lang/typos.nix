{
  flake.modules.homeManager.nvim =
    { config, lib, ... }:
    lib.mkIf (config.dev.languages ? typos) {
      programs.nixvim.plugins.lsp.servers.typos_lsp.enable = true;
    };
}
