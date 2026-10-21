{
  flake.modules.nixos.dracaena =
    { pkgs, ... }:
    {
      # otherwise `less`/systemctl's pager doesn't recognize TERM values
      # from local terminal emulators (e.g. ghostty) over SSH.
      # Not `enableAllTerminfo`: it pulls in contour, which fails to build.
      environment.systemPackages = [ pkgs.ghostty.terminfo ];
    };
}
