{
  flake.modules.nixos.yuxqiu-cedrus =
    { pkgs, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "usb_storage"
        "sd_mod"
        "rtsx_pci_sdmmc"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/142862d6-6393-4cf8-92e1-1e61a9cea266";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/EC63-2A5C";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

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

      # touchpad quirks, without overrides can only click but cannot move
      environment.etc."libinput/local-overrides.quirks".text = ''
        [Lenovo ThinkBook 16 G8+ IPH touchpad]
        MatchName=*GXTP5100*
        MatchDMIModalias=dmi:*svnLENOVO:*pvrThinkBook16G8+IPH*:*
        MatchUdevType=touchpad
        AttrInputProp=+INPUT_PROP_PRESSUREPAD
      '';
    };
}
