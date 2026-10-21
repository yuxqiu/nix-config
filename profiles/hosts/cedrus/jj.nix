{
  flake.modules.homeManager.cedrus =
    { config, ... }:
    {
      programs.jujutsu.settings.user = {
        name = config.my.user.name;
        email = config.my.user.email;
      };
    };
}
