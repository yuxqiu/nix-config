{
  flake.modules.generic.yuxqiu = {
    my.user = {
      name = "yuxqiu";
      email = "yuxqiu@proton.me";
      keys = {
        "general-ssh" =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtp1+EuAzwj3dfP6onSJDk/3arY6W6bgMyPC3BFk1bK yuxqiu+general-ssh@proton.me";
        "github-login" =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKBtmfn31tMjRZZdYzFXoiv3MKVbbq4cj7nvucqvHOIJ yuxqiu+github-login@proton.me";
        "github-sign" =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICf3yzISfsyM4+PCoz0LSGL+i9aECon/xvIF2YX5Dl3u yuxqiu+github-sign@proton.me";
      };
    };
  };

  flake.modules.nixos.yuxqiu =
    { pkgs, ... }:
    {
      users.users.yuxqiu = {
        isNormalUser = true;
        description = "yuxqiu";
        extraGroups = [
          "wheel"
          "docker"
          "i2c"
          "networkmanager"
          "geminicommit"
        ];
        initialPassword = "changeme";
        shell = pkgs.zsh;
      };
    };
}
