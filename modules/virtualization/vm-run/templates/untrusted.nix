# vm-run template `untrusted`: a plain guest that reaches the internet but
# nothing local (see packages/vm-run.nix).
{
  flake.modules.homeManager.vm-run.programs.vm-run.templates.untrusted =
    { pkgs, ... }:
    {
      vm-run.internet = true;
      environment.systemPackages = with pkgs; [
        curl
        git
      ];
    };
}
