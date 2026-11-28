{
  flake.modules.nixos.cedrus = {
    # Lets this host build for dracaena (aarch64) itself, under QEMU user-mode
    # emulation; the module also adds aarch64-linux to the daemon's
    # extra-platforms. Evaluating dracaena builds pstack (read at evaluation by
    # agent-skills-nix), and building it here keeps cedrus from having to
    # accept an unsigned copy from dracaena. Accepted: any aarch64 program now
    # runs on this host through QEMU.
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  };
}
