{
  flake.modules.homeManager.zed =
    { config, lib, ... }:
    {
      programs.zed-editor = {
        userSettings = {
          languages = lib.mkIf (config.my.dev.languages ? latex) {
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
          lsp = lib.mkIf (config.my.dev.languages ? latex) {
            texlab = {
              settings = {
                texlab = {
                  build = {
                    onSave = true;
                    forwardSearchAfter = true;
                  }
                  // (
                    if config.my.dev.latex.engine == "tectonic" then
                      {
                        executable = "tectonic";
                        args = [
                          "-X"
                          "compile"
                          "%f"
                          "--untrusted"
                          "--synctex"
                          "--keep-logs"
                          "--keep-intermediates"
                        ];
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
        extensions = lib.mkIf (config.my.dev.languages ? latex) [ "latex" ];
      };
    };
}
