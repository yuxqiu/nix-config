{
  flake.modules.homeManager.latex =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      # Editors (nvim, zed, vscode) read these to pick their compile command.
      options.dev.latex = {
        engine = lib.mkOption {
          type = lib.types.enum [
            "tectonic"
            "texlive"
          ];
          default = "tectonic";
          description = "LaTeX backend: tectonic, or texlive-full (compiled via latexmk).";
        };

        tectonicFlags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          readOnly = true;
          # Accepted by both `tectonic` and `tectonic -X compile` (checked
          # against `--help` of tectonic 0.17). Each editor appends its own
          # input file and output directory arguments.
          default = [
            # Disable shell-escape and other known-insecure features.
            "--untrusted"
            # Forward/inverse search between source and PDF viewer.
            "--synctex"
            # Keep the .log (error locations for the editor) and the .aux and
            # other intermediate files next to the PDF.
            "--keep-logs"
            "--keep-intermediates"
            # Still write a PDF when the document has errors.
            "-Z"
            "continue-on-errors"
          ];
          description = "Flags every editor passes to tectonic.";
        };
      };

      config.dev.languages.latex = {
        packages = [
          pkgs.texlab
        ]
        ++ (
          if config.dev.latex.engine == "tectonic" then
            [
              pkgs.tectonic
              (pkgs.texliveSmall.withPackages (
                ps: with ps; [
                  latexindent
                  synctex
                ]
              ))
            ]
          else
            # texliveFull already ships latexmk, latexindent and synctex.
            [ pkgs.texliveFull ]
        );
      };
    };
}
