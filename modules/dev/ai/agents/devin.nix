{
  flake.modules.homeManager.devin =
    { pkgs, ... }:
    {
      persistence.directories = [ ".local/share/devin" ];
      home.packages = [ pkgs.devin-cli ];

      agents-md.destinations.devin = ".config/devin/AGENTS.md";
    };
}
