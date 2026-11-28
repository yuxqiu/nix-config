# vm-run template `offline`: a plain guest with no network device at all.
{
  flake.modules.homeManager.vm-run.programs.vm-run.templates.offline =
    { pkgs, ... }:
    {
      vm-run.internet = false;
      environment.systemPackages = with pkgs; [ git ];
    };
}
