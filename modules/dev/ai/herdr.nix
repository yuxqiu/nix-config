{
  flake.modules.homeManager.herdr =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.herdr ];

      programs.agent-skills.sources.herdr = {
        path = pkgs.herdr;
        subdir = "share/skills/herdr";
      };
      programs.agent-skills.skills.enableAll = [ "herdr" ];
    };
}
