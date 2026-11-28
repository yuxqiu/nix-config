{
  flake.modules.homeManager.json =
    { pkgs, ... }:
    {
      dev.languages.json = {
        packages = with pkgs; [
          vscode-langservers-extracted
          prettier
        ];
      };
    };
}
