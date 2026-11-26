{
  flake.modules.nixos.pipewire = {
    home-manager.sharedModules = [
      {
        persistence.directories = [ ".local/state/wireplumber" ];
      }
    ];
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    security.rtkit.enable = true;
    programs.dconf.enable = true;

    # disable wireplumber bluetooth autoswitch to prevent
    # conflicts with easyeffects
    #
    # https://github.com/wwmm/easyeffects/issues/4878
    services.pipewire.wireplumber.extraConfig = {
      "bluetooth-profile" = {
        "wireplumber.settings" = {
          "bluetooth.autoswitch-to-headset-profile" = false;
        };
      };
    };
  };
}
