{
  flake.modules.homeManager.c =
    { pkgs, ... }:
    {
      dev.languages.c = {
        # clang-tools provides clangd, clang-format and clang-tidy.
        packages = with pkgs; [
          clang
          cmake
          clang-tools
        ];
      };
    };
}
