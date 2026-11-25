{
  flake.modules.nixos.cedrus = {
    # NixOS's polkit rule gives this group every NetworkManager and
    # ModemManager action without a password, so a process running as this
    # user can change system-wide DNS, VPN or proxy settings. Accepted: such
    # a process can already redirect this user's apps through their
    # environment and config files (systemctl --user set-environment,
    # environment.d, shell and terminal config), and without the group every
    # new or edited profile needs a password or becomes user-owned, which
    # only connects after login.
    users.users.yuxqiu.extraGroups = [ "networkmanager" ];
  };
}
