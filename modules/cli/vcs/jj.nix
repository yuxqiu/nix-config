{
  flake.modules.homeManager.jj =
    { config, ... }:
    {
      programs.jujutsu = {
        enable = true;
        settings = {
          user = {
            inherit (config.identity) name email;
          };
          signing = {
            behavior = "own";
            backend = "ssh";
            key = config.identity.keys."github-sign";
          };
        };
      };
    };
}
