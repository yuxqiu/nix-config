{
  flake.modules.homeManager.typst =
    { pkgs, ... }:
    {
      dev.languages.typst = {
        packages = with pkgs; [
          typst
          tinymist
        ];
      };
    };
}
