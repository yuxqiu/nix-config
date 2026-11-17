{
  flake.modules.nixos.sysctl = {
    boot.kernel.sysctl = {
      # ── Kernel pointer leaks ──
      "kernel.kptr_restrict" = 2; # Hide kernel pointers (NixOS default is 1)
      "kernel.dmesg_restrict" = 1; # Restrict dmesg to root (NOT default)

      # ── BPF hardening ──
      "net.core.bpf_jit_harden" = 2; # Full BPF JIT hardening
      "kernel.unprivileged_bpf_disabled" = 1; # No unprivileged BPF (NOT default)

      # ── TTY / LDISC ──
      "dev.tty.ldisc_autoload" = 0; # Prevent line discipline autoload

      # ── Filesystem hardening (NixOS defaults via systemd) ──
      "fs.protected_fifos" = 2; # Prevent FIFO abuse
      "fs.protected_regular" = 2; # Prevent /tmp race conditions
      "fs.suid_dumpable" = 0; # No core dumps from SUID programs

      # ── ASLR (tiny overhead, major security benefit) ──
      "kernel.randomize_va_space" = 2; # Full ASLR, incl. brk (also the kernel default without CONFIG_COMPAT_BRK)

      # ── Core dumps ──
      "kernel.core_pattern" = "|/bin/false"; # Prevent core dump files (NOT default)

      # ── SysRq (debug shortcut) ──
      "kernel.sysrq" = 0; # Disable SysRq key

      # ── Ptrace (minimal overhead) ──
      "kernel.yama.ptrace_scope" = 1; # Restrict ptrace to descendants (also Yama's default, YAMA_SCOPE_RELATIONAL)

      # ── Network: redirects (NOT default) ──
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
    };
  };
}
