_: {
  flake.modules.homeManager.hunk = { pkgs, ... }: {
    home.packages = with pkgs; [ hunk ];

    skills.sources.hunk = "${pkgs.hunk}/share/skills/hunk";
  };
}
