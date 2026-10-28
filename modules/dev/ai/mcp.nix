{
  flake.modules.homeManager.mcp = { pkgs, ... }: {
    programs.mcp = {
      enable = true;
    };

    home.packages = with pkgs; [ mcp-nixos ];
  };
}
