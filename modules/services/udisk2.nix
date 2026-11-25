{
  flake.modules.nixos.udisk2 = {
    services.udisks2.enable = true;

    # udisks lets the active session attach any readable disk-image file as a
    # loop device (allow_active=yes), and loop devices it set up then mount,
    # resize and unlock without a password. Mounting makes the kernel's
    # filesystem drivers parse an image the caller crafted, and block-device
    # filesystems cannot be mounted unprivileged otherwise (none set
    # FS_USERNS_MOUNT), so this is the user's path to that parser. Require
    # admin auth, as openSUSE's restrictive polkit profile does.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.udisks2.loop-setup") {
          return polkit.Result.AUTH_ADMIN_KEEP;
        }
      });
    '';
  };
}
