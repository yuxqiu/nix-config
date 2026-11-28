{
  flake.modules.homeManager.vscode =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      math = import ./_math-snippets.nix {
        languageId = "typst";
        displayDelimiters = {
          open = "$$";
          close = "$$";
        };
      };
    in
    lib.mkIf (config.dev.languages ? typst) {
      programs.vscode.profiles.default = {
        extensions = with pkgs.vscode-marketplace; [ myriad-dreamin.tinymist ];

        userSettings = {
          "tinymist.formatterMode" = "typstyle";
          "tinymist.formatterIndentSize" = 4;
          "[typst]" = {
            "editor.wordWrap" = "on";
            "editor.wordSeparators" = ''`~!@#$%^&*()=+[{]}\|;:'",.<>/?'';
          };
          "[typst-code]" = {
            "editor.wordSeparators" = ''`~!@#$%^&*()=+[{]}\|;:'",.<>/?'';
          };
        };

        inherit (math) keybindings languageSnippets;
      };
    };
}
