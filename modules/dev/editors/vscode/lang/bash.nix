{
  flake.modules.homeManager.vscode =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs.vscode.profiles.default.extensions = lib.mkIf (config.dev.languages ? bash) (
        with pkgs.vscode-marketplace; [ remisa.shellman ]
      );
    };
}
