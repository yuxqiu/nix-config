{
  flake.modules.homeManager.python =
    { pkgs, ... }:
    {
      dev.languages.python = {
        # ruff is both formatter and linter.
        packages = with pkgs; [
          uv
          python3
          basedpyright
          ruff
        ];
      };
    };
}
