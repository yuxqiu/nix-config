{
  flake.modules.nixos.weylus =
    { lib, pkgs, ... }:
    let
      # H-M-H/weylus commit nixpkgs builds; the fork below is checked
      # against it.
      checkedUpstreamRev = "38a01a8f8e429500c7e9f67fc1c88ca37a4d1e93";
    in
    {
      warnings = lib.optional (pkgs.weylus.src.rev != checkedUpstreamRev) ''
        weylus.nix: nixpkgs' weylus now builds H-M-H/weylus ${pkgs.weylus.src.rev}. If it
        includes binarin's DMA-BUF capture fix (H-M-H/weylus#560), remove the
        programs.weylus.package override and this warning; otherwise set
        checkedUpstreamRev to that commit.
      '';

      programs.weylus = {
        enable = true;
        openFirewall = true;
        # H-M-H/weylus black-screens on niri: glupload fails to link when a
        # restrictive DMABuf capsfilter feeds it with no GL context yet.
        # binarin's fork carries the DMA-BUF capture negotiation fix.
        package = pkgs.weylus.overrideAttrs (old: rec {
          version = "unstable-2026-07-30";
          src = pkgs.fetchFromGitHub {
            owner = "binarin";
            repo = "weylus";
            rev = "808a2a0929be73c96089d50ca0466121619f18b2";
            hash = "sha256-2S/EvwDtrVz9nFbE8HTNkJA/S7G6T4VG5SLQJV90GAA=";
          };
          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            inherit src;
            hash = "sha256-aokIFGGxxihKZNO7uzTu+dCShdPb5avBKR1koguEH+o=";
          };
        });
      };

      # Stylus and multi-touch go through /dev/uinput. Grant it to the active
      # local session via logind's uaccess ACL instead of programs.weylus.users,
      # whose uinput group would also cover the user's SSH and inactive sessions.
      services.udev.extraRules = ''
        SUBSYSTEM=="misc", KERNEL=="uinput", TAG+="uaccess", OPTIONS+="static_node=uinput"
      '';
    };
}
