{
  flake.modules.homeManager.bash-lang =
    { pkgs, ... }:
    {
      dev.languages.bash = {
        packages = with pkgs; [
          bash-language-server
          shfmt
          shellcheck
        ];
      };
    };
}
