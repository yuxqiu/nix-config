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
        languageId = "latex";
        displayDelimiters = {
          open = "\\[";
          close = "\\]";
        };
      };
    in
    lib.mkIf (config.dev.languages ? latex) {
      programs.vscode.profiles.default = {
        extensions = with pkgs.vscode-marketplace; [ james-yu.latex-workshop ];

        userSettings = {
          # Open PDFs in latex-workshop's viewer (keeps SyncTeX working).
          "workbench.editorAssociations" = {
            "*.pdf" = "latex-workshop-pdf-hook";
          };
          "latex-workshop.latex.outDir" = "%DIR%/latex-build";
          # latex-workshop builds with the first recipe by default.
          "latex-workshop.latex.recipes" =
            let
              tectonic = {
                name = "tectonic";
                tools = [ "tectonic" ];
              };
              latexmk = {
                name = "latexmk";
                tools = [ "latexmk" ];
              };
            in
            if config.dev.latex.engine == "tectonic" then
              [
                tectonic
                latexmk
              ]
            else
              [
                latexmk
                tectonic
              ];
          "latex-workshop.latex.tools" = [
            {
              name = "tectonic";
              command = "tectonic";
              args = config.dev.latex.tectonicFlags ++ [
                "--outdir=%OUTDIR%"
                "%DOC_EXT%"
              ];
              env = { };
            }
            {
              name = "latexmk";
              command = "latexmk";
              args = [
                "-synctex=1"
                "-interaction=nonstopmode"
                "-file-line-error"
                "-pdf"
                "-outdir=%OUTDIR%"
                "%DOC%"
              ];
              env = { };
            }
          ];
          "latex-workshop.view.pdf.internal.synctex.keybinding" = "double-click";
          "latex-workshop.latex.autoBuild.run" = "never";
          "latex-workshop.formatting.latex" = "latexindent";
          "[latex]" = {
            "editor.wordWrap" = "on";
            "editor.guides.bracketPairs" = false;
            "editor.defaultFormatter" = "James-Yu.latex-workshop";
          };
          "umath.preview.EnableCursor" = false;
          "umath.preview.renderer" = "katex";
          "umath.preview.AutoAdjustPreviewPosition" = false;
        };

        inherit (math) keybindings languageSnippets;
      };
    };
}
