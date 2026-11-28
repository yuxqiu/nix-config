{
  flake.modules.homeManager.vscode =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs.vscode.profiles.default.extensions = lib.mkIf (config.dev.languages ? typos) (
        with pkgs.vscode-marketplace; [ tekumara.typos-vscode ]
      );
    };
}
