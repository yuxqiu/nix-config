{
  flake.modules.homeManager.mcp = { pkgs, ... }: {
    programs.mcp = {
      enable = true;
    };

    # TODO: enable once mcp-nixos -> >=3.1.0
    # home.packages = with pkgs; [ mcp-nixos ];
  };
}
