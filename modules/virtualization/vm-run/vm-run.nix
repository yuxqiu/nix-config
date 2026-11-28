# vm-run: throwaway microVMs built from templates (packages/vm-run.nix).
#
# Each template in `programs.vm-run.templates` is a NixOS module added to the
# guest base below and built into a microvm.nix runner. Templates live in
# ./templates, one file each.
{ inputs, ... }:
{
  flake.modules.homeManager.vm-run =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.programs.vm-run;

      # Shared with the launcher (packages/vm-run.nix), which needs the same
      # values. They are the same in every guest and on every run, so the
      # guests all look alike to the programs inside them.
      guest = {
        workMount = "/work";
        guestUser = "user";
        # The first uid NixOS gives a normal user, and the `users` group.
        guestUid = 1000;
        guestGid = 100;
        # An address no network uses; pasta answers DNS on it.
        guestDns = "169.254.1.1";
      };
      # Where the run's seed directory (vm-run.seed) is mounted in the guest.
      seedMount = "/run/vm-run-seed";

      # Every guest: the per-run plumbing vm-run relies on, and nothing from
      # the host unless a template adds it (no store share, no host config).
      guestBase =
        { config, lib, ... }:
        {
          imports = [ inputs.microvm.nixosModules.microvm ];

          options.vm-run = {
            user = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = guest.guestUser;
              description = "The guest's login user.";
            };
            internet = lib.mkOption {
              type = lib.types.bool;
              description = "Whether the guest gets a network device with internet access (and nothing local; see packages/vm-run.nix).";
            };
            seed = lib.mkOption {
              type = lib.types.nullOr lib.types.package;
              default = null;
              description = ''
                A program vm-run runs on the host, as the calling user, before
                each boot, with an empty directory as its argument. What it
                puts there is copied into the guest user's home at boot (paths
                relative to the home, owner the guest user).
              '';
            };
          };

          config = {
            # The guest reuses the host's package set, so its packages are the
            # ones already built or cached for the host.
            nixpkgs.pkgs = pkgs;
            # Nothing in the guest outlives a run, so no state migration ever
            # depends on this.
            system.stateVersion = lib.trivial.release;

            microvm = {
              hypervisor = "qemu";
              # The CPU model: microvm.nix's `-cpu host` here, replaced per run
              # by vm-run's choice (VM_RUN_CPU below; see packages/vm-run.nix).
              # Defaults; `vm-run --cpus/--mem` override them per run.
              vcpu = lib.mkDefault 2;
              mem = lib.mkDefault 4096;
              # No control socket: a run ends by killing QEMU.
              socket = null;
              # Per-run QEMU arguments, from the environment vm-run sets: the
              # vsock device for SSH, the run's public key as a systemd
              # credential, the run's work directory and the seed as 9p
              # shares, the CPU
              # model, and the CPU count and memory when given (for repeated
              # -cpu, -smp and -m QEMU takes the later value). Devices are the
              # virtio-mmio (`-device`) variants on QEMU's `microvm` machine
              # (x86_64), which has no PCI bus, and PCI ones elsewhere
              # (aarch64's `virt`).
              extraArgsScript =
                let
                  bus = if config.microvm.qemu.machine == "microvm" then "device" else "pci";
                in
                "${pkgs.writeShellScript "vm-run-qemu-args" ''
                  args="-device vhost-vsock-${bus},guest-cid=$VM_RUN_CID"
                  args+=" -fw_cfg name=opt/io.systemd.credentials/vm-run.authorized_keys,file=$VM_RUN_DIR/key.pub"
                  # security_model=none: files keep their owner, which vm-run's
                  # user namespace shows as the guest user.
                  # multidevs=remap: the mapped directories are separate
                  # filesystems, and remapping keeps their inode numbers from
                  # colliding in the guest.
                  args+=" -fsdev local,id=work,path=$VM_RUN_DIR/work,security_model=none,multidevs=remap"
                  args+=" -device virtio-9p-${bus},fsdev=work,mount_tag=work"
                  if [ -n "''${VM_RUN_SEED:-}" ]; then
                    args+=" -fsdev local,id=seed,path=$VM_RUN_SEED,security_model=none,readonly=on"
                    args+=" -device virtio-9p-${bus},fsdev=seed,mount_tag=seed"
                    args+=" -fw_cfg name=opt/io.systemd.credentials/vm-run.seed,string=1"
                  fi
                  if [ -n "''${VM_RUN_CPU:-}" ]; then args+=" -cpu $VM_RUN_CPU"; fi
                  if [ -n "''${VM_RUN_CPUS:-}" ]; then args+=" -smp $VM_RUN_CPUS"; fi
                  if [ -n "''${VM_RUN_MEM:-}" ]; then args+=" -m $VM_RUN_MEM"; fi
                  echo "$args"
                ''}";
            };

            # The work share is always there (vm-run maps directories into
            # it); the seed share only when the template has a seed, so its
            # mount waits for the credential vm-run passes along with it.
            systemd.mounts = [
              {
                what = "work";
                where = guest.workMount;
                type = "9p";
                options = "trans=virtio,version=9p2000.L";
                wantedBy = [ "multi-user.target" ];
              }
            ]
            ++ lib.optional (config.vm-run.seed != null) {
              what = "seed";
              where = seedMount;
              type = "9p";
              options = "trans=virtio,version=9p2000.L,ro";
              wantedBy = [ "multi-user.target" ];
              unitConfig.ConditionCredential = "vm-run.seed";
            };

            # Copied rather than used in place, so programs can rewrite them
            # (token refreshes) without touching the host's copies.
            systemd.services.vm-run-seed = lib.mkIf (config.vm-run.seed != null) {
              wantedBy = [ "multi-user.target" ];
              before = [ "sshd.service" ];
              unitConfig = {
                RequiresMountsFor = seedMount;
              };
              serviceConfig = {
                Type = "oneshot";
                User = config.vm-run.user;
                Group = "users";
              };
              script = ''
                cp -rT --no-preserve=ownership ${seedMount} "$HOME"
              '';
            };

            # The guest's side of vm-run's network (packages/vm-run.nix):
            # QEMU's user-mode network, inside a namespace that reaches only
            # the internet. DNS goes to pasta's forwarder; the user-mode
            # network's own DNS address would ask the namespace's empty
            # loopback.
            microvm.interfaces = lib.mkIf config.vm-run.internet [
              {
                type = "user";
                id = "net0";
                # QEMU's default NIC address (net/net.c), the most common one.
                mac = "52:54:00:12:34:56";
              }
            ];
            networking = {
              useNetworkd = true;
              useDHCP = false;
            };
            systemd.network.networks."10-uplink" = lib.mkIf config.vm-run.internet {
              matchConfig.Type = "ether";
              networkConfig.DHCP = "ipv4";
              dhcpV4Config.UseDNS = false;
              dns = [ guest.guestDns ];
            };

            users = {
              mutableUsers = false;
              # The login key arrives at boot (vm-run-authorized-keys below),
              # so the build sees no key and would otherwise refuse.
              allowNoPasswordLogin = true;
              users.${config.vm-run.user} = {
                isNormalUser = true;
                # vm-run maps the caller's uid to this one, so mapped
                # files belong to the guest user.
                uid = guest.guestUid;
                group = "users";
                extraGroups = [ "wheel" ];
              };
            };
            # Root in a throwaway guest is not a boundary worth a password.
            security.sudo.wheelNeedsPassword = false;

            services.openssh = {
              enable = true;
              # Reached over vsock only.
              openFirewall = false;
              settings = {
                PasswordAuthentication = false;
                KbdInteractiveAuthentication = false;
                PermitRootLogin = "no";
              };
            };
            # The run's public key arrives as a systemd credential; sshd reads
            # keys from /etc/ssh/authorized_keys.d/%u on NixOS.
            systemd.services.vm-run-authorized-keys = {
              wantedBy = [ "multi-user.target" ];
              before = [ "sshd.service" ];
              serviceConfig = {
                Type = "oneshot";
                ImportCredential = "vm-run.authorized_keys";
              };
              script = ''
                install -D -m 0444 "$CREDENTIALS_DIRECTORY/vm-run.authorized_keys" \
                  /etc/ssh/authorized_keys.d/${config.vm-run.user}
              '';
            };

            documentation.enable = false;
            # Templates that want `nix` in the guest turn it on.
            nix.enable = lib.mkDefault false;
          };
        };

      # What the launcher needs from a template: its runner and seed program.
      launcherTemplate =
        _name: template:
        let
          guestConfig =
            (inputs.nixpkgs.lib.nixosSystem {
              modules = [
                guestBase
                template
              ];
            }).config;
        in
        {
          runner = guestConfig.microvm.declaredRunner;
          inherit (guestConfig.vm-run) seed;
        };
    in
    {
      options.programs.vm-run = {
        templates = lib.mkOption {
          type = lib.types.attrsOf lib.types.deferredModule;
          description = "vm-run templates: NixOS modules added to the guest base, by template name.";
        };
      };

      config = {
        # .cache/vm-run is not kept for its contents (each run deletes its
        # own directory) but so that runs' disk images live on disk rather
        # than in the tmpfs home. .local/share/vm-run holds state templates
        # keep across runs (the agent template's install ids).
        persistence.directories = [
          ".cache/vm-run"
          ".local/share/vm-run"
        ];

        home.packages = [
          (inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.vm-run.override (
            guest // { templates = lib.mapAttrs launcherTemplate cfg.templates; }
          ))
        ];
      };
    };
}
