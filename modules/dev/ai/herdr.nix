{
  flake.modules.homeManager.herdr =
    { config, ... }:
    {
      programs.herdr = {
        enable = true;
        settings = {
          onboarding = false;
          experimental.kitty_graphics = true;
          ui.sound.enabled = false;
          ui.toast.delivery = "terminal";
          update.version_check = false;
          update.manifest_check = false;
        };
      };

      programs.agent-skills = {
        sources = {
          herdr.path = config.programs.herdr.package;
          herdr.subdir = "share/skills/herdr";
        };

        skills.enableAll = [ "herdr" ];
      };
    };
}
