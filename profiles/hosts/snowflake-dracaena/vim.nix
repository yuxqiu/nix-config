{
  flake.modules.nixos.snowflake-dracaena = {
    programs.vim = {
      enable = true;
      defaultEditor = true;
    };
  };
}
