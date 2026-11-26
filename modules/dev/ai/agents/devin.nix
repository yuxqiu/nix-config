{
  flake.modules.homeManager.devin =
    { pkgs, ... }:
    {
      persistence.directories = [ ".local/share/devin" ];
      home.packages = [ pkgs.devin-cli ];

      my.agents-md.destinations.devin = ".config/devin/AGENTS.md";
    };
}
