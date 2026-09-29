{
  flake.modules.homeManager.latex =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      # Editors (nvim, zed, vscode) read this to pick their compile command.
      options.my.dev.latex.engine = lib.mkOption {
        type = lib.types.enum [
          "tectonic"
          "texlive"
        ];
        default = "tectonic";
        description = "LaTeX backend: tectonic, or texlive-full (compiled via latexmk).";
      };

      config.my.dev.languages.latex =
        if config.my.dev.latex.engine == "tectonic" then
          {
            toolchain = [ pkgs.tectonic ];
            lsp = [ pkgs.texlab ];
            formatter = pkgs.texliveSmall.withPackages (
              ps: with ps; [
                latexindent
                synctex
              ]
            );
          }
        else
          {
            # texliveFull already ships latexmk, latexindent and synctex.
            toolchain = [ pkgs.texliveFull ];
            lsp = [ pkgs.texlab ];
          };
    };
}
