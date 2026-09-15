{
  flake.modules.homeManager.nvim =
    {
      config,
      lib,
      ...
    }:
    lib.mkIf (config.my.dev.languages ? lean) {
      programs.nixvim.plugins.lean = {
        enable = true;
        settings = {
          mappings = true;
          lsp.enable = true;
        };
      };
      # elan (via toolchain) already provides lean/lake on PATH, respecting
      # each project's lean-toolchain pin. Don't pull in nixvim's own
      # lean4 package as an extra dependency.
      programs.nixvim.dependencies.lean.enable = false;
    };
}
