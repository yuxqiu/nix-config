{ inputs, ... }:
{
  flake.modules.homeManager.headup = {
    imports = [ inputs.headup.homeManagerModules.default ];

    services.headup.enable = true;
  };
}
