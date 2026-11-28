{
  flake.modules.homeManager.go =
    { pkgs, ... }:
    {
      dev.languages.go = {
        # go provides gofmt.
        packages = with pkgs; [
          go
          gopls
          golangci-lint
        ];
      };
    };
}
