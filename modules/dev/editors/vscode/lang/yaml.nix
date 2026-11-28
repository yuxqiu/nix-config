{
  flake.modules.homeManager.vscode =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs.vscode.profiles.default.extensions = lib.mkIf (config.dev.languages ? yaml) (
        with pkgs.vscode-marketplace; [ redhat.vscode-yaml ]
      );
    };
}
