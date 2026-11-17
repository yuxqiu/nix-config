{
  inputs,
  ...
}:
{
  flake.modules.nixos.dms = {
    imports = [
      inputs.dank-greeter.nixosModules.default
    ];

    programs.dms-greeter = {
      enable = true;
      compositor.name = "niri";
    };
  };
}
