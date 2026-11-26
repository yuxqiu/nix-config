{
  flake.modules.homeManager.gh = _: {
    persistence.directories = [ ".config/gh" ];
    programs.gh = {
      enable = true;

      settings = {
        git_protocol = "ssh";
      };
    };
  };
}
