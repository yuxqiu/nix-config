{
  flake.modules.homeManager.lean =
    { pkgs, ... }:
    {
      dev.languages.lean = {
        # elan installs each project's pinned lean/lake toolchain.
        packages = [ pkgs.elan ];
      };
    };
}
