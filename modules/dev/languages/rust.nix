{
  flake.modules.homeManager.rust =
    { pkgs, ... }:
    {
      dev.languages.rust = {
        # rustup provides cargo, rustc, rust-analyzer, rustfmt and clippy,
        # following each project's rust-toolchain pin.
        packages = [ pkgs.rustup ];
      };
    };
}
