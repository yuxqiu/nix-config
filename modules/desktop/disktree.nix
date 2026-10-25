{
  flake.modules.homeManager.disktree =
    { pkgs, ... }:
    {
      # TODO: enable once upstream build succeeds
      # home.packages = [ pkgs.disktree ];
    };
}
