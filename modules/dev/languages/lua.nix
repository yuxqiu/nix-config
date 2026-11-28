{
  flake.modules.homeManager.lua =
    { pkgs, ... }:
    {
      dev.languages.lua = {
        packages = with pkgs; [
          lua-language-server
          stylua
        ];
      };
    };
}
