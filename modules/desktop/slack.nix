{
  flake.modules.homeManager.slack =
    { pkgs, ... }:
    {
      persistence.directories = [
        {
          directory = ".config/Slack";
          mode = "0700";
        }
      ];
      home.packages = with pkgs; [ slack ];
    };
}
