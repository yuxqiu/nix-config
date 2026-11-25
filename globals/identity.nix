{ lib, ... }:
{
  # The person who owns this flake, available in every NixOS and Home Manager
  # config through `generic.base`. Login account names are set per host.
  flake.modules.generic.base = {
    options.identity = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Full name, for tool identity (e.g. VCS commit author)";
      };
      email = lib.mkOption {
        type = lib.types.str;
        description = "Email address, for tool identity (e.g. VCS commit author)";
      };
      keys = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Personal public keys";
      };
    };

    config.identity = {
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
}
