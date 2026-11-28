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
        languageId = "markdown";
        displayDelimiters = {
          open = "$$";
          close = "$$";
        };
      };
    in
    lib.mkIf (config.dev.languages ? markdown) {
      programs.vscode.profiles.default = {
        extensions = with pkgs.vscode-marketplace; [
          bierner.markdown-mermaid
          foam.foam-vscode
          robole.markdown-shortcuts
          yzhang.markdown-all-in-one
        ];

        userSettings = {
          "markdown.extension.list.indentationSize" = "inherit";
          "markdown.extension.print.theme" = "dark";
          "markdown.updateLinksOnFileMove.enabled" = "prompt";
        };

        inherit (math) keybindings languageSnippets;
      };
    };
}
