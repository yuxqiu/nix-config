{
  flake.modules.homeManager.fence =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [ fence ];

      xdg.configFile."fence/fence.json".text = builtins.toJSON {
        extends = "code-relaxed";

        filesystem = {
          # --- NixOS-specific fixes ---
          #
          # The upstream templates target FHS distributions where binaries live
          # in /usr/bin, /bin, etc.  On NixOS everything is under /nix/store,
          # so Landlock deny-by-default blocks every command.
          allowRead = [ "/nix/store/**" ];
        };

        # The tool blocks "chroot" at runtime by resolving binary paths.
        # On NixOS coreutils is a single multi-call binary, so blocking
        # chroot collaterally blocks cat, ls, echo, etc.  This option
        # skips that runtime block for the shared binary.
        command = {
          acceptSharedBinaryCannotRuntimeDeny = [ "chroot" ];
        };

        networking = {
          allowLocalBinding = true;
          allowLocalOutbound = true;
        };
      };
    };
}
