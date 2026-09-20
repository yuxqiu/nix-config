{ inputs, ... }:
{
  flake.modules.homeManager.agent-orchestrator =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.callPackage (inputs.self + /packages/agent-orchestrator.nix) { })
      ];
    };
}
