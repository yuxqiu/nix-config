{
  flake.modules.nixos.yuxqiu =
    { pkgs, ... }:
    {
      users.users.yuxqiu = {
        isNormalUser = true;
        description = "yuxqiu";
        extraGroups = [ "wheel" ];
        shell = pkgs.zsh;
      };
    };
}
