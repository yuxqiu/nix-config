{
  flake.modules.homeManager.vscode =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      programs.vscode.profiles.default.extensions = lib.mkIf (config.dev.languages ? python) (
        with pkgs.vscode-marketplace;
        [
          charliermarsh.ruff
          ms-python.debugpy
          ms-python.python
          ms-python.vscode-pylance
          ms-python.vscode-python-envs
          ms-toolsai.jupyter
          ms-toolsai.jupyter-keymap
          ms-toolsai.jupyter-renderers
          ms-toolsai.vscode-jupyter-cell-tags
          ms-toolsai.vscode-jupyter-slideshow
        ]
      );

      programs.vscode.profiles.default.userSettings = lib.mkIf (config.dev.languages ? python) {
        "python.experiments.enabled" = false;
        "python.testing.pytestEnabled" = true;
        "python.analysis.typeCheckingMode" = "basic";
        "jupyter.experiments.enabled" = false;
        "python.analysis.diagnosticMode" = "workspace";
        "python.analysis.inlayHints.variableTypes" = true;
        "python.analysis.inlayHints.functionReturnTypes" = true;
        "python.terminal.activateEnvironment" = false;
        "[python]" = {
          "editor.defaultFormatter" = "charliermarsh.ruff";
        };
        "python.analysis.completeFunctionParens" = true;
        "notebook.lineNumbers" = "on";
      };
    };
}
