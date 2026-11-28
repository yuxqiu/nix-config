{
  flake.modules.homeManager.zed =
    { config, lib, ... }:
    {
      programs.zed-editor = {
        userSettings.languages = lib.mkIf (config.dev.languages ? nix) {
          Nix = {
            language_servers = [
              "nixd"
              "!nil"
            ];
            formatter = {
              external = {
                command = "nixfmt";
              };
            };
          };
        };
        extensions = lib.mkIf (config.dev.languages ? nix) [ "nix" ];
      };
    };
}
