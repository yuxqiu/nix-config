# AirDrop with iPhones/Macs: DMS AirDrop plugin (UI) -> omdrop 0.14.1 (CLI +
# receiver) -> omdrop-owl (root radio helper, AWDL in userspace through OWL).
#
# Upstream targets Arch, with the helper at /usr/lib/omdrop; here every
# reference to it is patched to the omdrop-owl store path. The system's polkit
# action and the HM-side omdrop CLI must name the same store path, otherwise
# pkexec asks for a password: both evaluate packages/omdrop-owl.nix.
{ inputs, ... }:
let
  mkOmdropOwl = pkgs: pkgs.callPackage (inputs.self + /packages/omdrop-owl.nix) { };
in
{
  flake.modules.nixos.dms =
    { pkgs, ... }:
    {
      # Installs the polkit action letting the active session pkexec the helper.
      environment.systemPackages = [ (mkOmdropOwl pkgs) ];

      # OWL's tap (awdl0), monitor (mon0) and ad-hoc (awdlibss0) interfaces.
      networking.networkmanager.unmanaged = [
        "interface-name:awdl0"
        "interface-name:mon0"
        "interface-name:awdlibss0"
      ];

      # The receiver, on awdl0 only (upstream's ufw rule).
      networking.firewall.interfaces.awdl0.allowedTCPPorts = [ 8771 ];
    };

  flake.modules.homeManager.dms =
    { pkgs, lib, ... }:
    let
      omdrop-owl = mkOmdropOwl pkgs;
      omdrop = pkgs.callPackage (inputs.self + /packages/omdrop.nix) { inherit omdrop-owl; };
      omdropDir = "${omdrop}/share/omdrop";
    in
    {
      # Where the DMS plugin looks first, and on PATH via home.sessionPath.
      home.file.".local/bin/omdrop".source = "${omdropDir}/bin/omdrop";

      # First-run setup (self-signed identity, device name, link handler),
      # which the DMS plugin refuses to do itself. Only while no identity exists.
      home.activation.omdropSetup = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -e "$HOME/.omdrop/keys/certificate.self-signed.pem" ]; then
          run ${omdropDir}/bin/omdrop setup || echo "omdrop setup failed; run it by hand" >&2
        fi
      '';

      # What `omdrop setup` would write, byte for byte: the DMS plugin refuses
      # to start if the installed unit differs from the rendered template.
      # Not enabled; `omdrop on` starts it for each receive window.
      xdg.configFile."systemd/user/airdrop-receiver.service".source =
        pkgs.runCommand "airdrop-receiver.service" { }
          ''
            substitute ${omdropDir}/share/airdrop-receiver.service $out \
              --replace-fail @PLUGIN_DIR@ ${omdropDir}
          '';

      # omdrop would otherwise run `xdg-mime default`, replacing the
      # HM-managed mimeapps.list symlink with a file.
      xdg.mimeApps.defaultApplications = {
        "application/x-mswinurl" = "netmojo.omdrop-links.desktop";
        "application/x-webloc" = "netmojo.omdrop-links.desktop";
      };

      programs.dank-material-shell.plugins.dmsAirDrop = {
        enable = true;
        # Replaces the registry's copy, to point it at the helper's store path.
        src = lib.mkForce (
          pkgs.applyPatches {
            name = "dms-airdrop";
            src = pkgs.fetchFromGitHub {
              owner = "Kratospidey";
              repo = "dms-airdrop";
              rev = "4bc4076210fb4344ec6212bcb3741357dd027bba"; # follow:branch main
              hash = "sha256-c76Z8MUVOBqDegJd0eQ3dFa7PgZLtjL74Q3vxmUlD1M=";
            };
            postPatch = ''
              substituteInPlace scripts/backend.py \
                --replace-fail /usr/lib/omdrop/omdrop-discoverable \
                  ${omdrop-owl}/lib/omdrop/omdrop-discoverable
            '';
          }
        );
      };
    };
}
