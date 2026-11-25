{
  flake.modules.homeManager.geminicommit =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Declared under `programs` so that if Home Manager adds its own
      # `programs.geminicommit`, the duplicate option fails evaluation and this
      # module gets reviewed.
      options.programs.geminicommit.configFile = lib.mkOption {
        # A string, not a path: a Nix path would copy the API key into the store.
        type = lib.types.str;
        example = "/run/secrets/geminicommit.toml";
        description = "geminicommit config file (TOML with the API key), passed as --config.";
      };

      config.home.packages = [
        (pkgs.symlinkJoin {
          name = "geminicommit";
          paths = [ pkgs.geminicommit ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram "$out/bin/geminicommit" \
              --add-flags "--config ${config.programs.geminicommit.configFile}"
          '';
        })
      ];
    };
}
