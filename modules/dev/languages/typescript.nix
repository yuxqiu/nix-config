{
  flake.modules.homeManager.typescript =
    { pkgs, ... }:
    {
      dev.languages.typescript = {
        packages = with pkgs; [
          typescript-language-server
          prettier
        ];
      };
    };
}
