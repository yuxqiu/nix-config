{
  flake.modules.homeManager.cedrus =
    { config, ... }:
    {
      programs.jujutsu.settings.user = {
        name = config.identity.name;
        email = config.identity.email;
      };
    };
}
