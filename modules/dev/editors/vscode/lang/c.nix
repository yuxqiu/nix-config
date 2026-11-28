{
  flake.modules.homeManager.vscode =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs.vscode.profiles.default.extensions = lib.mkIf (config.dev.languages ? c) (
        with pkgs.vscode-marketplace;
        [
          cschlosser.doxdocgen
          hars.cppsnippets
          llvm-vs-code-extensions.vscode-clangd
          ms-vscode.cmake-tools
          xaver.clang-format
        ]
      );

      programs.vscode.profiles.default.userSettings = lib.mkIf (config.dev.languages ? c) {
        "clangd.arguments" = [
          "--background-index"
          "--compile-commands-dir=\${workspaceFolder}"
          "--clang-tidy"
          "--completion-style=detailed"
          "--enable-config"
          "--pretty"
        ];
        "clangd.fallbackFlags" = [
          "-Wall"
          "-Werror"
          "-Wextra"
          "-Wpedantic"
          "-Wvla"
          "-Wextra-semi"
          "-Wnull-dereference"
          "-Wsuggest-override"
          "-Wconversion"
        ];
        "clangd.checkUpdates" = false;
        "clang-format.style" = "Webkit";
        "[cpp]" = {
          "editor.defaultFormatter" = "xaver.clang-format";
        };
        "[c]" = {
          "editor.defaultFormatter" = "xaver.clang-format";
        };
        "cmake.configureOnOpen" = true;
        "cmake.showOptionsMovedNotification" = false;
      };
    };
}
