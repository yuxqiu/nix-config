{
  flake.modules.homeManager.nix-lang =
    { pkgs, ... }:
    {
      dev.languages.nix = {
        packages = with pkgs; [
          nixd
          nixfmt
          deadnix
          statix
        ];
      };
    };
}
