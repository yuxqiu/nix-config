{ inputs, ... }:
{
  flake.modules.homeManager.opencode =
    {
      lib,
      pkgs,
      mv,
      ...
    }:
    let
      opencodeQueue = pkgs.callPackage (inputs.self + /packages/opencode-queue.nix) { };
      # nixpkgs' opencode 2.2.5 node_modules hash was computed with bun 1.4.2
      # (NixOS/nixpkgs#581607); bun 1.4.4 (NixOS/nixpkgs#577354) landed after
      # and changes the output, so the FOD fails. Pin the last good version.
      brokenNodeModulesHash = "sha256-xfOVcw1+waLVNhFDwzOtzxrUSQEogvn88YomydOlhwc=";
      # Broken is the pair (hash, bun 1.4.4): nixpkgs may also fix it by building
      # node_modules with another bun while keeping the hash.
      nodeModulesBun =
        lib.findFirst (p: (p.pname or "") == "bun")
          (throw "opencode.nix: bun not found in opencode.node_modules.nativeBuildInputs")
          pkgs.opencode.node_modules.nativeBuildInputs;
      upstreamFixed =
        pkgs.opencode.node_modules.outputHash != brokenNodeModulesHash || nodeModulesBun.version != "1.4.4";
    in
    {
      warnings = lib.optional upstreamFixed ''
        nixpkgs' opencode (${pkgs.opencode.version}) node_modules changed from the build broken by bun 1.4.4
        (hash ${pkgs.opencode.node_modules.outputHash}, bun ${nodeModulesBun.version}).
        Try dropping the multiverse pin `mv.versions.opencode."2.2.1"` in modules/dev/ai/agents/opencode.nix.
      '';

      # Other Interesting Plugins
      # - opencode-background-agents (seems a bit overkill)
      # - open-ralph-wiggum
      # - opencode-dynamic-context-pruning (useful with token-based plan)
      programs.opencode = {
        enable = true;
        enableMcpIntegration = true;
        package = mv.versions.opencode."2.2.1";
        mutableSettings = true;
        settings = {
          autoupdate = false;
        };
        cli = {
          attention = {
            notifications = true;
            sound = false;
          };
        };
      };

      # opencode-queue plugin - queue input until session is idle
      # https://github.com/mirsella/opencode-queue
      home.file.".config/opencode/plugins/opencode-queue.js".source =
        "${opencodeQueue}/lib/opencode-queue/index.js";

      programs.agent-skills.targets.opencode.enable = true;

      my.agents-md.destinations.opencode = ".config/opencode/AGENTS.md";
    };
}
