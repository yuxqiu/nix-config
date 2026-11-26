{
  flake.modules.homeManager.slack =
    { pkgs, ... }:
    {
      persistence.directories = [ ".config/Slack" ];
      home.packages = with pkgs; [ slack ];
    };
}
