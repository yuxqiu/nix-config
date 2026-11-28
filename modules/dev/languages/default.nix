{
  flake.modules.homeManager.languages =
    { lib, config, ... }:
    {
      # Editor wiring lives in editors/<editor>/lang/<lang>.nix, guarded by
      # `config.dev.languages ? <lang>`.
      options.dev.languages = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = "Toolchain, language servers, formatters and linters; installed into home.packages.";
              };
            };
          }
        );
        default = { };
      };

      config.home.packages = lib.concatMap (lang: lang.packages) (lib.attrValues config.dev.languages);
    };
}
