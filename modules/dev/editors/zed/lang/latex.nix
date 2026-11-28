{
  flake.modules.homeManager.zed =
    { config, lib, ... }:
    {
      programs.zed-editor = {
        userSettings = {
          languages = lib.mkIf (config.dev.languages ? latex) {
            BibTeX = {
              formatter = {
                external = {
                  command = "latexindent";
                  arguments = [
                    "-l"
                    "-g"
                    "/dev/null"
                  ];
                };
              };
            };
            LaTeX = {
              soft_wrap = "editor_width";
            };
          };
          lsp = lib.mkIf (config.dev.languages ? latex) {
            texlab = {
              settings = {
                texlab = {
                  build = {
                    onSave = true;
                    forwardSearchAfter = true;
                  }
                  // (
                    if config.dev.latex.engine == "tectonic" then
                      {
                        executable = "tectonic";
                        args = [
                          "-X"
                          "compile"
                          "%f"
                        ]
                        ++ config.dev.latex.tectonicFlags;
                      }
                    else
                      {
                        executable = "latexmk";
                        args = [
                          "-pdf"
                          "-interaction=nonstopmode"
                          "-synctex=1"
                          "%f"
                        ];
                      }
                  );
                };
              };
            };
          };
        };
        extensions = lib.mkIf (config.dev.languages ? latex) [ "latex" ];
      };
    };
}
