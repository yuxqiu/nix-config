{
  flake.modules.nixos.accountservice = {
    persistence.directories = [ "/var/lib/AccountsService" ];
    services.accounts-daemon.enable = true;
  };
}
