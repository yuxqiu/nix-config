{
  flake.modules.nixos.cedrus =
    { config, ... }:
    {
      programs.dms-greeter.configHome = config.users.users.yuxqiu.home;
    };
}
