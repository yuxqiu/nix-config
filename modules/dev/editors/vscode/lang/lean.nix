{
  flake.modules.homeManager.vscode =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs.vscode.profiles.default.extensions = lib.mkIf (config.dev.languages ? lean) (
        with pkgs.vscode-marketplace; [ leanprover.lean4 ]
      );
    };
}
