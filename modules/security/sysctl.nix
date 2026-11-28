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

      # ── Filesystem hardening ──
      # systemd's sysctl.d/50-default.conf sets protected_fifos/regular to 1
      # (refuse O_CREAT on another user's FIFO/file in world-writable sticky
      # directories); 2 extends that to group-writable sticky directories.
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
      # No core dumps from SUID programs (systemd's sysctl.d/50-coredump.conf sets 2)
      "fs.suid_dumpable" = 0;

      # ── ASLR (tiny overhead, major security benefit) ──
      "kernel.randomize_va_space" = 2; # Full ASLR, incl. brk (also the kernel default without CONFIG_COMPAT_BRK)

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
