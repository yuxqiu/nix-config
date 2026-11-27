{ lib, ... }:
let
  entries =
    description:
    lib.mkOption {
      type = with lib.types; listOf (either str attrs);
      default = [ ];
      inherit description;
    };
in
{
  # State a module needs to survive a reboot on hosts whose root is wiped at
  # boot. Declared for every NixOS and Home Manager config so any module can
  # set it; only the ephemeral-root module reads it, so elsewhere it has no
  # effect. NixOS paths are absolute, Home Manager paths relative to the home
  # directory. Entries are passed to nix-community/preservation unchanged (a
  # path, or an attribute set such as { directory = ...; mode = ...; }). Its
  # tmpfiles rules set the declared owner and mode at every boot, so an entry
  # whose path is not root's (or the user's) with mode 0755 (0644 for a file)
  # declares them, from upstream's options where they exist. When the program
  # sets the mode itself at every start, the entry uses `programSetsMode`.
  flake.modules.generic.base = {
    options.persistence = {
      # For a kept directory whose program sets its mode at every start
      # (systemd re-applies StateDirectoryMode=/CacheDirectoryMode=; usbmuxd
      # chmods /var/lib/lockdown). The ":" is tmpfiles' create-only form: it
      # never changes an existing directory, so the program's mode is the
      # only one applied. Under preservation systemd has already made the
      # directory when mounting it, so the number is not used either; if
      # tmpfiles ever creates the directory, 0700 makes it too strict rather
      # than too loose until the program starts and sets its own mode.
      programSetsMode = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = ":0700";
        description = "Mode for a kept directory whose program sets its own mode at every start.";
      };
      directories = entries "Directories to keep across reboots.";
      # A kept file is a bind mount, which rename() cannot replace: list a
      # file only if its program writes it in place, otherwise keep its
      # directory.
      files = entries "Files to keep across reboots; only files written in place.";
    };
  };
}
