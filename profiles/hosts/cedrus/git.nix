{
  flake.modules.homeManager.cedrus =
    { config, ... }:
    {
      programs.git.settings.user = {
        name = config.my.user.name;
        email = config.my.user.email;
      };
    };
}
