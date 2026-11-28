{
  flake.modules.nixos.cedrus = {
    # Lets this host build aarch64 systems (dracaena) itself, under QEMU
    # user-mode emulation; the module also adds aarch64-linux to the daemon's
    # extra-platforms. Used by `os-switch <host> <target> --build-on local`
    # and by `os-install`, whose nixos-anywhere then builds here by default
    # (`--build-on auto` finds that this host can build aarch64). Accepted:
    # any aarch64 program now runs on this host through QEMU.
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  };
}
