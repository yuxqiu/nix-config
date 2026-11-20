{ config, inputs, ... }:
{
  # Every host decrypts secrets; the module stands alone so the VM tests can
  # load it without the rest of the base.
  flake.modules.nixos.base.imports = [ config.flake.modules.nixos.sops ];

  flake.modules.nixos.sops =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      keyFile = "/var/lib/sops-nix/key.txt";
      # sops-nix's own generateKey runs plain `age-keygen`, which makes a
      # classic X25519 key. Once its module passes -pq anywhere, use it instead.
      upstreamGeneratesPq = lib.any (f: lib.hasInfix "-pq" (builtins.readFile f)) (
        lib.filesystem.listFilesRecursive "${inputs.sops-nix}/modules/sops"
      );
    in
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
      ];

      # Each host decrypts with its own post-quantum (hybrid ML-KEM-768 +
      # X25519) age key, made on the host at first activation so the private
      # key never leaves it. `<key>.pub` holds its recipient for .sops.yaml.
      sops.age.keyFile = keyFile;
      # sops-nix otherwise derives classic keys from the SSH host keys.
      sops.age.sshKeyPaths = lib.mkDefault [ ];

      system.activationScripts.generate-pq-age-key = {
        deps = [ "specialfs" ];
        text = ''
          # Traversable by everyone so key.txt.pub can be read without root;
          # key.txt itself is 0600 (age-keygen creates it so).
          mkdir -p ${dirOf keyFile}
          chmod 0755 ${dirOf keyFile}
          if [ ! -f ${keyFile} ]; then
            ${pkgs.age}/bin/age-keygen -pq -o ${keyFile}
          fi
          if [ ! -f ${keyFile}.pub ]; then
            ${pkgs.age}/bin/age-keygen -y ${keyFile} > ${keyFile}.pub
            chmod 0644 ${keyFile}.pub
          fi
        '';
      };
      # sops-nix defines setupSecrets only when there are secrets not needed
      # for users (its modules/sops/default.nix, `setupSecrets = lib.mkIf`).
      system.activationScripts.setupSecrets = lib.mkIf (config.sops.secrets != { }) {
        deps = [ "generate-pq-age-key" ];
      };

      # The key must exist before sops-nix installs secrets. Only the
      # setupSecrets activation snippet is ordered after it: the systemd
      # variant and secrets needed for users install from elsewhere.
      assertions = [
        {
          assertion =
            !config.sops.useSystemdActivation
            && lib.all (s: !s.neededForUsers) (lib.attrValues config.sops.secrets);
          message = "modules/base/nixos/sops.nix: generate-pq-age-key is only ordered before the setupSecrets activation snippet; order it before sops.useSystemdActivation's unit or setupSecretsForUsers too.";
        }
      ];

      warnings = lib.optional upstreamGeneratesPq "modules/base/nixos/sops.nix: sops-nix now passes -pq to age-keygen. Replace the generate-pq-age-key activation snippet (and its setupSecrets dependency) with sops.age.generateKey and its post-quantum setting, write ${keyFile}.pub some other way if upstream doesn't, then remove this warning.";

      # Lets sops-update/sops-update-key run sops on this host with its key.
      environment.systemPackages = [ pkgs.sops ];
    };
}
