{
  config,
  ...
}:

{
  configurations.nixos = {
    "yuxqiu-cedrus" = {
      system = "x86_64-linux";
      stateVersion = "26.11";
      modules = [
        config.flake.modules.generic.base
        config.flake.modules.generic.yuxqiu
        config.flake.modules.generic.yuxqiu-cedrus

        # base
        config.flake.modules.nixos.base
        config.flake.modules.nixos.console

        # hardware
        config.flake.modules.nixos.i2c

        config.flake.modules.nixos.graphics
        config.flake.modules.nixos.tuned
        config.flake.modules.nixos.bluetooth
        config.flake.modules.nixos.fstrim
        config.flake.modules.nixos.bolt
        config.flake.modules.nixos.thermald
        config.flake.modules.nixos.fwupd

        # networking
        config.flake.modules.nixos.dns
        config.flake.modules.nixos.networking
        config.flake.modules.nixos.nm
        config.flake.modules.nixos.firewall
        config.flake.modules.nixos.opensnitch
        config.flake.modules.nixos.tailscale
        # config.flake.modules.nixos.xray

        # security
        config.flake.modules.nixos.polkit
        config.flake.modules.nixos.sysctl
        config.flake.modules.nixos.coredump
        config.flake.modules.nixos.geoclue
        config.flake.modules.nixos.usbguard
        config.flake.modules.nixos.bt-proximity-lock

        # services
        config.flake.modules.nixos.time
        config.flake.modules.nixos.earlyoom
        config.flake.modules.nixos.journald
        config.flake.modules.nixos.logind
        config.flake.modules.nixos.accountservice
        config.flake.modules.nixos.udisk2
        config.flake.modules.nixos.upower
        config.flake.modules.nixos.ios
        config.flake.modules.nixos.libinput
        config.flake.modules.nixos.fprintd
        config.flake.modules.nixos.udev
        config.flake.modules.nixos.printing

        # gaming
        config.flake.modules.nixos.steam

        # virtualization
        config.flake.modules.nixos.docker

        # desktop
        config.flake.modules.nixos.display-manager
        config.flake.modules.nixos.pipewire
        config.flake.modules.nixos.dms
        config.flake.modules.nixos.hister
        config.flake.modules.nixos.niri
        config.flake.modules.nixos.xdg
        config.flake.modules.nixos.xremap
        config.flake.modules.nixos.localsend
        config.flake.modules.nixos.gpu-screen-recorder
        config.flake.modules.nixos.flatpak
        config.flake.modules.nixos.edgepad
        config.flake.modules.nixos.nautilus
        config.flake.modules.nixos.weylus

        # dev
        config.flake.modules.nixos.geminicommit
        config.flake.modules.nixos.nix-ld
        config.flake.modules.nixos.man

        # user
        config.flake.modules.nixos.yuxqiu
        config.flake.modules.nixos.yuxqiu-cedrus

        # hostname
        { networking.hostName = "pc"; }
      ];
      homeManager.username = "yuxqiu";
      homeManager.stateVersion = "26.11";
      homeManager.modules = [
        config.flake.modules.generic.base
        config.flake.modules.generic.yuxqiu
        config.flake.modules.generic.yuxqiu-cedrus

        # base
        config.flake.modules.homeManager.base
        config.flake.modules.homeManager.base-linux
        config.flake.modules.homeManager.base-linux-desktop

        # cli
        config.flake.modules.homeManager.fzf
        config.flake.modules.homeManager.session
        config.flake.modules.homeManager.bash
        config.flake.modules.homeManager.zsh
        config.flake.modules.homeManager.ssh
        config.flake.modules.homeManager.ssh-copy-id
        config.flake.modules.homeManager.ssh-agent
        config.flake.modules.homeManager.git
        config.flake.modules.homeManager.gh
        config.flake.modules.homeManager.jj
        config.flake.modules.homeManager.proton-pass-cli

        # desktop
        config.flake.modules.homeManager.firefox
        config.flake.modules.homeManager.captive-browser
        config.flake.modules.homeManager.ghostty
        config.flake.modules.homeManager.dms
        config.flake.modules.homeManager.nautilus
        config.flake.modules.homeManager.fcitx5
        config.flake.modules.homeManager.xcompose
        config.flake.modules.homeManager.flatpak
        config.flake.modules.homeManager.handy
        config.flake.modules.homeManager.hister
        config.flake.modules.homeManager.idescriptor
        config.flake.modules.homeManager.loupe
        config.flake.modules.homeManager.pinta
        config.flake.modules.homeManager.rnote
        config.flake.modules.homeManager.niri
        config.flake.modules.homeManager.obs
        config.flake.modules.homeManager.slack
        config.flake.modules.homeManager.zoom
        config.flake.modules.homeManager.pointer
        config.flake.modules.homeManager.mdbrowse
        config.flake.modules.homeManager.terminal-browser
        config.flake.modules.homeManager.quicksnip
        config.flake.modules.homeManager.sioyek
        config.flake.modules.homeManager.stylix
        config.flake.modules.homeManager.gtk
        config.flake.modules.homeManager.qt
        config.flake.modules.homeManager.wayscriber
        config.flake.modules.homeManager.wlr-which-key
        config.flake.modules.homeManager.xdg
        config.flake.modules.homeManager.jan
        config.flake.modules.homeManager.edgepad

        # dev (ai)
        config.flake.modules.homeManager.agent-lsp
        config.flake.modules.homeManager.browser
        config.flake.modules.homeManager.harness
        config.flake.modules.homeManager.herdr
        config.flake.modules.homeManager.hunk
        config.flake.modules.homeManager.mcp
        config.flake.modules.homeManager.skills
        config.flake.modules.homeManager.agents-md
        config.flake.modules.homeManager.antigravity
        config.flake.modules.homeManager.claude
        config.flake.modules.homeManager.codex
        config.flake.modules.homeManager.devin
        config.flake.modules.homeManager.opencode
        config.flake.modules.homeManager.omp

        # dev
        config.flake.modules.homeManager.editorconfig
        config.flake.modules.homeManager.languages
        config.flake.modules.homeManager.nvim
        # config.flake.modules.homeManager.zed
        config.flake.modules.homeManager.python
        config.flake.modules.homeManager.rust
        config.flake.modules.homeManager.go
        config.flake.modules.homeManager.c
        # config.flake.modules.homeManager.sage
        config.flake.modules.homeManager.bash-lang
        config.flake.modules.homeManager.latex
        config.flake.modules.homeManager.lua
        config.flake.modules.homeManager.markdown
        config.flake.modules.homeManager.nix-lang
        config.flake.modules.homeManager.toml
        config.flake.modules.homeManager.typst
        config.flake.modules.homeManager.typos
        config.flake.modules.homeManager.yaml
        config.flake.modules.homeManager.typescript
        config.flake.modules.homeManager.json
        config.flake.modules.homeManager.css
        config.flake.modules.homeManager.lean
        config.flake.modules.homeManager.fence
        config.flake.modules.homeManager.hyperfine
        config.flake.modules.homeManager.poop

        # networking (home-manager)
        config.flake.modules.homeManager.nm
        config.flake.modules.homeManager.opensnitch
        config.flake.modules.homeManager.proton-vpn
        config.flake.modules.homeManager.usbguard
        config.flake.modules.homeManager.bluetooth
        # config.flake.modules.homeManager.xray

        # nix
        config.flake.modules.homeManager.nix
        config.flake.modules.homeManager.nix-index
        config.flake.modules.homeManager.nix-update
        config.flake.modules.homeManager.hydra-check
        config.flake.modules.homeManager.nh
        config.flake.modules.homeManager.direnv
        config.flake.modules.homeManager.any-nix-shell

        # sound
        config.flake.modules.homeManager.lowfi
        config.flake.modules.homeManager.easyeffects

        # virtualization (home-manager)
        config.flake.modules.homeManager.docker
        config.flake.modules.homeManager.distrobox

        # fonts
        config.flake.modules.homeManager.fonts

        # services
        config.flake.modules.homeManager.printing

        # user
        config.flake.modules.homeManager.yuxqiu-cedrus
      ];
    };
  };
}
