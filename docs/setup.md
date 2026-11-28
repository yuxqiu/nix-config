# Setting up a machine

Secrets use [sops-nix](https://github.com/Mic92/sops-nix) with post-quantum
age keys. Each host has its own key. The key is made and granted access before
the host first runs its config, so the host decrypts its secrets from the
first boot. An admin key kept in Proton Pass grants access.

## 1. Describe the host

- Create `profiles/hosts/<host>/default.nix` with
  `configurations.nixos.<host>` (start from the closest existing host). Include
  the accounts it needs from `profiles/users/` and set `networking.hostName`.
- To add an account, create `profiles/users/<account>.nix`, which sets
  `flake.modules.nixos.<account>` to the account's `users.users.<account>`.
  Then list `config.flake.modules.nixos.<account>` in the host's modules.
  - **Starting point:** copy an existing account file: one with a password
    login for a desktop, or a key-only one with a locked password
    (`hashedPassword = "!"`) for SSH-only access.
  - **SSH keys:** reference public keys from `globals/identity.nix` by name,
    for example
    `openssh.authorizedKeys.keys = [ config.identity.keys."general-ssh" ];`.
    For a new key, add it to `identity.keys` there first.
  - **Password:** on a host with an ephemeral root, the login password comes from
    sops (step 3).
- Add the host to `globals/tailnet.nix` as
  `<host> = "<hostName>.<tailnet>.ts.net";`. SSH aliases (`ssh <host>`) and
  services that address each other use it. The MagicDNS name follows
  `networking.hostName`, not the flake output name.

## 2. Create its secrets file

1. Add a `.sops.yaml` rule for `profiles/hosts/<host>/secrets/<host>.yaml`
   that lists only the admin key.
2. Create the file with `sops-update admin <file>`.
3. If the host joins the tailnet, put a Tailscale auth key in it as
   `tailscale_key`, read by `nixos.tailscale`.
4. `git add` everything.

## 3. Decide on an ephemeral root

An ephemeral root is optional. With it, `/` is a tmpfs, and only the paths that
modules list in `persistence` survive a reboot
([ephemeral-root.md](ephemeral-root.md)). A host that uses it includes
`nixos.ephemeral-root` and sets what [Opting in](ephemeral-root.md#opting-in)
lists:

- A `persistence.nix` with the persistent filesystem (`neededForBoot = true`)
  and `persistence.storage` set to its mount point. Which filesystem depends on
  the install route (below).
- Each login user's password hash in the secrets file as `<user>-password`,
  made with `mkpasswd -m yescrypt`. `os-install` and `os-bootstrap` stop while a
  hash is missing.

## 4. Install

There are two routes: a remote machine that is wiped, or a local machine
installed with the NixOS graphical installer.

### Remote: wipe and install with `os-install`

The host needs a `disko.nix` that describes the whole disk. nixos-anywhere
wipes the disk and formats it from that file. With an ephemeral root, use the
[recommended layout](ephemeral-root.md#recommended-disk-layout): btrfs
subvolumes `@nix` at `/nix` and `@persist` at `/persist`, with `@persist` as
the persistent filesystem.

1. Run `os-install <host> root@<public ip>`. It makes and grants the host's
   key, so the host decrypts its secrets from the first boot. A failed install
   restores `.sops.yaml` and the secrets file.
2. Commit `.sops.yaml`, the secrets file and `_hardware-configuration.nix`.

To reinstall, run `os-install` again. The host gets a new key. On a host with
an ephemeral root, add `--keep-state` to keep its state instead. The kept paths and
the existing key are copied from the running machine into memory, then
restored before the first boot.

### Local: graphical installer, then `os-bootstrap`

Steps marked *(ephemeral root)* apply only to a host that uses it.

1. Install NixOS with the graphical installer, with any layout.
   *(ephemeral root)* Choose btrfs, turn encryption on, and set swap to "none".
   The installer puts `/` on the btrfs top level, with subvolumes `home` and
   `nix`.
2. *(ephemeral root)* In the host's `persistence.nix`, make that top level,
   which is the running root now, the persistent filesystem. Use the device
   of the generated `/nix` entry:

   ```nix
   fileSystems."/persist" = {
     device = "/dev/disk/by-uuid/<btrfs uuid>";
     fsType = "btrfs";
     options = [ "subvol=/" "compress=zstd" "noatime" ];
     neededForBoot = true;
   };
   persistence.storage = "/persist";
   ```
3. In a checkout of this repository on that machine, run
   `nix --extra-experimental-features 'nix-command flakes' develop .#bootstrap`.
   It provides the tools and prints the steps.
4. Run `os-bootstrap <host>` until it says *Ready*. It makes and grants the
   key, copies the hardware configuration to `_hardware-configuration.nix`,
   and lists secrets that are still missing.
5. *(ephemeral root)* Delete `fileSystems."/"` and `fileSystems."/home"` from
   `_hardware-configuration.nix`. From now on, edit that file instead of
   rerunning `nixos-generate-config`, which would write them back.
6. Run the `nixos-rebuild boot` command that `os-bootstrap` prints, then
   reboot.
7. *(ephemeral root)* Check that `findmnt /` shows a tmpfs. If the new
   generation fails, choose the previous one in the boot menu: it boots the
   old root unchanged.

*(ephemeral root)* The old root's files stay in `/persist` after the switch.
Once you will not roll back:

1. Delete the older generations with `sudo nix-collect-garbage -d`, so
   nothing boots the old root any more.
2. Delete from `/persist` what no kept path uses: the old root's `bin` and
   `usr`, and unkept files under `etc`, `var` and the homes. Garbage
   collection frees only `/nix`, not these files.
