{
  flake.modules.nixos.dracaena =
    { lib, ... }:
    {
      # earlyoom's shared extraArgs target desktop process names
      # (browser tabs, niri, greetd); none apply on a headless box.
      services.earlyoom = {
        enableNotifications = lib.mkForce false;
        extraArgs = lib.mkForce [ ];
      };
    };
}
