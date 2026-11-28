{
  # Gives each systemd user manager its own kernel session keyring. Without
  # one, the user manager and every app it launches fall back to the
  # user-session keyring (_uid_ses), where keys are not possessed: keyctl
  # search finds nothing or fails with EACCES, which breaks keyutils-backed
  # credential stores such as proton-pass-cli's kernel keyring backend.
  flake.modules.nixos.session-keyring =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      pamModule = builtins.readFile "${pkgs.path}/nixos/modules/security/pam.nix";
    in
    {
      # Same line and position (right after pam_loginuid) as systemd's
      # upstream etc/pam.d/systemd-user, which NixOS's generated stack omits.
      security.pam.services.systemd-user.rules.session.keyinit = {
        order = config.security.pam.services.systemd-user.rules.session.loginuid.order + 1;
        control = "optional";
        modulePath = "${config.security.pam.package}/lib/security/pam_keyinit.so";
        args = [
          "force"
          "revoke"
        ];
      };

      warnings = lib.optional (lib.hasInfix "pam_keyinit" pamModule) ''
        session-keyring.nix: nixpkgs' PAM module now references pam_keyinit. Check whether
        /etc/pam.d/systemd-user already gets it; if so, delete modules/security/session-keyring.nix
        (including this warning) and its entry in profiles/hosts/cedrus/default.nix.
      '';
    };
}
