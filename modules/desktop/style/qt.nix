{
  flake.modules.homeManager.qt =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Copy of stylix's Kvantum theme with translucent menus for niri
      # `popups` blur. Kvantum draws menu shadows inside the popup surface,
      # which niri would blur too, so drop them.
      stylixTheme =
        lib.findFirst (p: p.name == "base16-kvantum")
          (throw "qt.nix: stylix's base16-kvantum theme not found in qt.kvantum.themes")
          config.qt.kvantum.themes;
      base = "${stylixTheme}/share/Kvantum/Base16Kvantum";
      name = "Base16KvantumBlur";
      menuOpacity = toString (100 - builtins.floor (config.stylix.opacity.popups * 100 + 0.5));
      kvconfig = pkgs.runCommandLocal "${name}.kvconfig" { } ''
        sed -e 's/^menu_shadow_depth=.*/menu_shadow_depth=0/' \
            -e 's/^reduce_menu_opacity=.*/reduce_menu_opacity=${menuOpacity}/' \
            ${base}/Base16Kvantum.kvconfig > $out
        grep -qx 'menu_shadow_depth=0' $out
        grep -qx 'reduce_menu_opacity=${menuOpacity}' $out
      '';
    in
    {
      qt = {
        enable = true;
        platformTheme.name = "qtct";
        style.name = "kvantum";
        kvantum.settings.General.theme = lib.mkForce name;
      };

      xdg.configFile = {
        "Kvantum/${name}/${name}.kvconfig".source = kvconfig;
        "Kvantum/${name}/${name}.svg".source = "${base}/Base16Kvantum.svg";
      };

      stylix.targets.qt.enable = true;
    };
}
