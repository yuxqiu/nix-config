{
  flake.modules.homeManager.python =
    { pkgs, ... }:
    {
      my.dev.languages.python = {
        toolchain = with pkgs; [
          uv
          python3
        ];
        lsp = [ pkgs.basedpyright ];
        formatter = pkgs.ruff;
        linter = [ pkgs.ruff ];
      };
    };
}
