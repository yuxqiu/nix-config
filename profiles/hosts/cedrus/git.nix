{
  flake.modules.homeManager.cedrus =
    { config, ... }:
    {
      programs.git.settings.user = {
        name = config.identity.name;
        email = config.identity.email;
      };
    };
}
