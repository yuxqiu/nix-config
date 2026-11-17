{
  flake.modules.homeManager.fonts =
    { pkgs, ... }:
    {
      fonts.fontconfig.enable = true;

      home.packages = with pkgs; [
        # Default
        # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/fonts/packages.nix
        dejavu_fonts
        freefont_ttf
        gyre-fonts
        liberation_ttf
        unifont
        noto-fonts-color-emoji

        # Chinese
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
      ];

      fonts.fontconfig = {
        antialiasing = true;
        hinting = "slight";
        subpixelRendering = "none";

        defaultFonts = {
          sansSerif = [
            "Noto Sans"
            "Noto Sans CJK SC"
            "DejaVu Sans"
          ];
          serif = [
            "Noto Serif"
            "Noto Serif CJK SC"
            "DejaVu Serif"
          ];
          monospace = [
            "DejaVu Sans Mono"
            "Noto Sans Mono CJK SC"
          ];
          # emoji: stylix sets [ "Noto Color Emoji" ]; the list isn't deduplicated.
        };
      };
    };
}
