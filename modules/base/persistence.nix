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
  # set it; only the impermanence module reads it, so elsewhere it has no
  # effect. NixOS paths are absolute, Home Manager paths relative to the home
  # directory. Entries are passed to nix-community/impermanence unchanged (a
  # path, or an attribute set such as { directory = ...; mode = ...; }).
  flake.modules.generic.base = {
    options.persistence = {
      directories = entries "Directories to keep across reboots.";
      # A kept file is a bind mount, which rename() cannot replace: list a
      # file only if its program writes it in place, otherwise keep its
      # directory.
      files = entries "Files to keep across reboots; only files written in place.";
    };
  };
}
