{
  flake.modules.nixos.cedrus = {
    sops.secrets."geminicommit.toml" = {
      mode = "0400";
      owner = "yuxqiu";
    };
  };

  flake.modules.homeManager.cedrus =
    { osConfig, ... }:
    {
      programs.geminicommit.configFile = osConfig.sops.secrets."geminicommit.toml".path;
    };
}
