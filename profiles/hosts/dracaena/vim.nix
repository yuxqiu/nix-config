{
  flake.modules.nixos.dracaena = {
    programs.vim = {
      enable = true;
      defaultEditor = true;
    };
  };
}
