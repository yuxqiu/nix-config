{
  flake.modules.homeManager.yaml =
    { pkgs, ... }:
    {
      dev.languages.yaml = {
        packages = with pkgs; [
          yaml-language-server
          prettier
          yamllint
        ];
      };
    };
}
