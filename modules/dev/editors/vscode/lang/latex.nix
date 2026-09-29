{
  flake.modules.homeManager.vscode =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs.vscode.profiles.default.extensions = lib.mkIf (config.my.dev.languages ? latex) (
        with pkgs.vscode-marketplace; [ james-yu.latex-workshop ]
      );

      programs.vscode.profiles.default.userSettings = lib.mkIf (config.my.dev.languages ? latex) {
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
          if config.my.dev.latex.engine == "tectonic" then
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
            args = [
              "--synctex"
              "--outdir=%OUTDIR%"
              "-Z"
              "continue-on-errors"
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
          "editor.desktopdes.bracketPairs" = false;
          "editor.defaultFormatter" = "James-Yu.latex-workshop";
        };
        "umath.preview.EnableCursor" = false;
        "umath.preview.renderer" = "katex";
        "umath.preview.AutoAdjustPreviewPosition" = false;
      };

      programs.vscode.profiles.default.keybindings = lib.mkIf (config.my.dev.languages ? latex) [
        {
          key = "ctrl+m ctrl+m";
          command = "editor.action.insertSnippet";
          args = {
            name = "Insert Inline Math";
          };
          when = "editorTextFocus && !editorReadonly && editorLangId == 'latex'";
        }
        {
          key = "ctrl+shift+m";
          command = "editor.action.insertSnippet";
          args = {
            name = "Insert Display Math";
          };
          when = "editorTextFocus && !editorReadonly && editorLangId == 'latex'";
        }
      ];

      programs.vscode.profiles.default.languageSnippets = lib.mkIf (config.my.dev.languages ? latex) {
        latex = {
          "Insert Inline Math" = {
            "prefix" = "inlineMath";
            "body" = [ "\${1:$\${2:}$$0}" ];
            "description" = "Insert inline math block $$ $$ with easy backspace delete";
          };
          "Insert Display Math" = {
            "prefix" = "displayMath";
            "body" = [
              "\${1:\\["
              "    \${2:}"
              "\\]}$0"
            ];
            "description" = "Insert 3-line display math block with cursor inside";
          };
        };
      };
    };
}
