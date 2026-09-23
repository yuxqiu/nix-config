{ inputs, ... }:
{
  flake.modules.homeManager.herdr =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      tsk = pkgs.callPackage (inputs.self + /packages/tsk.nix) { };
    in
    {
      programs.herdr = {
        enable = true;
        settings = {
          onboarding = false;
          experimental.kitty_graphics = true;
          ui.sound.enabled = false;
          ui.toast.delivery = "terminal";
          keys.command = [
            {
              key = "prefix+t";
              type = "plugin_action";
              command = "herdr-tsk.open-board";
            }
            {
              key = "prefix+a";
              type = "plugin_action";
              command = "herdr-tsk.quick-capture";
            }
          ];
        };
      };

      home.packages = [ tsk ];

      programs.agent-skills = {
        sources = {
          herdr.path = config.programs.herdr.package;
          herdr.subdir = "share/skills/herdr";

          tsk-cli.path = tsk;
          tsk-cli.subdir = "share/skills";
        };

        skills.enableAll = [
          "herdr"
          "tsk-cli"
        ];
      };

      # Registers tsk as a local herdr plugin. Idempotent: re-linking the
      # same path on every switch is a no-op.
      home.activation.tskHerdrPlugin = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ${lib.getExe config.programs.herdr.package} plugin link ${tsk}/share/tsk-herdr-plugin --enabled
      '';
    };
}
