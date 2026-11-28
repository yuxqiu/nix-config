{
  flake.modules.nixos.xremap =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.xremap;
      yaml = pkgs.formats.yaml { };
    in
    {
      options.services.xremap.settings = lib.mkOption {
        inherit (yaml) type;
        description = "xremap configuration, written as its YAML config file (https://github.com/xremap/xremap#configuration).";
      };

      config = {
        # /dev/uinput owned by group uinput, mode 0660.
        hardware.uinput.enable = true;

        # A system service with its own dynamic user, so no login user needs
        # the input or uinput group (either lets every process the user runs
        # read or inject keystrokes). The remaps are device-only modmaps, which
        # need no compositor IPC from inside the user session.
        systemd.services.xremap = {
          description = "xremap key remapper";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${lib.getExe pkgs.xremap} --watch ${yaml.generate "xremap.yml" cfg.settings}";
            DynamicUser = true;
            # Read and grab /dev/input/event* (root:input), create the
            # remapped device through /dev/uinput (root:uinput).
            SupplementaryGroups = [
              "input"
              "uinput"
            ];
            Restart = "on-failure";
            # Key events pass through this process; upstream's NixOS module
            # (xremap/nix-flake system-service.nix) uses the same niceness.
            Nice = -20;

            CapabilityBoundingSet = "";
            DevicePolicy = "closed";
            DeviceAllow = [
              "char-input rw"
              "/dev/uinput rw"
            ];
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            PrivateNetwork = true;
            ProcSubset = "pid";
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            RestrictAddressFamilies = "AF_UNIX";
            RestrictNamespaces = true;
            RestrictRealtime = true;
            SystemCallArchitectures = "native";
            SystemCallFilter = [
              "@system-service"
              "~@privileged @resources"
            ];
          };
        };
      };
    };
}
