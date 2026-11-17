{
  flake.modules.homeManager.vscode =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs.vscode.profiles.default.extensions = lib.mkIf (config.my.dev.languages ? rust) (
        with pkgs.vscode-marketplace;
        [
          rust-lang.rust-analyzer
          vadimcn.vscode-lldb
        ]
      );

      programs.vscode.profiles.default.userSettings = lib.mkIf (config.my.dev.languages ? rust) {
        "lldb.launch.terminal" = "integrated";
      };
    };
}
