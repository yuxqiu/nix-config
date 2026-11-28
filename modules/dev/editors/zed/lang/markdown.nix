{
  flake.modules.homeManager.zed =
    { config, lib, ... }:
    {
      programs.zed-editor = {
        extensions = lib.mkIf (config.dev.languages ? markdown) [ "markdown-oxide" ];
      };
    };
}
