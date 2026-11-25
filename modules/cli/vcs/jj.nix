{
  flake.modules.homeManager.jj =
    { config, ... }:
    {
      programs.jujutsu = {
        enable = true;
        settings = {
          signing = {
            behavior = "own";
            backend = "ssh";
            key = config.identity.keys."github-sign";
          };
        };
      };
    };
}
