_: {
  flake.modules.homeManager.agent-browser =
    { pkgs, ... }:
    let
      # chrome-headless-shell instead of the full `chromium`, which phones home
      # (GCM, component updater, account checks, DoH probes) even with
      # --disable-background-networking. Same binary as packages/vellum-nvim.nix.
      # Always headless, so `--headed` has no effect.
      headless-shell =
        let
          arch = if pkgs.stdenv.hostPlatform.isAarch64 then "linux-arm64" else "linux64";
        in
        "${pkgs.playwright-driver.components.chromium-headless-shell}/chrome-headless-shell-${arch}/chrome-headless-shell";

      agentBrowser = pkgs.symlinkJoin {
        name = "agent-browser";
        paths = [ pkgs.agent-browser ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/agent-browser \
            --set AGENT_BROWSER_EXECUTABLE_PATH ${headless-shell}
        '';
      };
    in
    {
      home.packages = [
        agentBrowser
        pkgs.chromium
      ];

      programs.agent-skills = {
        sources.agent-browser = {
          path = pkgs.agent-browser;
          subdir = "skills";
        };

        skills.enableAll = [
          "agent-browser"
        ];
      };
    };
}
