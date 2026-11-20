{
  flake.modules.nixos.cedrus =
    { pkgs, ... }:
    {
      boot.loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot = {
          enable = true;
          configurationLimit = 5;
          # Windows and NixOS share the same ESP, so systemd-boot auto-detects
          # the Windows Boot Manager entry without any extra config.
          # BitLocker is on this disk with an active TPM: chain-loading Windows
          # through systemd-boot changes the TPM PCR values Windows expects,
          # which would otherwise trigger a recovery-key prompt every boot.
          rebootForBitlocker = true;
        };
      };

      hardware.cpu.intel.npu.enable = true;
      hardware.cpu.intel.updateMicrocode = true;
      hardware.sensor.iio.enable = true;

      # enable hardware decoding
      hardware.graphics.extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
        intel-compute-runtime
      ];
    };
}
