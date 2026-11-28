{
  flake.modules.homeManager.herdr =
    { config, ... }:
    {
      persistence.directories = [ ".local/share/herdr-board" ];
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

      skills.sources.herdr = "${config.programs.herdr.package}/share/skills/herdr";
    };
}
