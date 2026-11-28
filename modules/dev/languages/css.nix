{
  flake.modules.homeManager.css =
    { pkgs, ... }:
    {
      dev.languages.css = {
        packages = with pkgs; [
          vscode-langservers-extracted
          prettier
        ];
      };
    };
}
