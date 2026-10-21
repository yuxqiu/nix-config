{
  flake.modules.nixos.dracaena = {
    boot.kernelModules = [ "tcp_bbr" ];
    boot.kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";

      "net.core.rmem_max" = 33554432;
      "net.core.wmem_max" = 33554432;
      "net.ipv4.tcp_rmem" = "4096 87380 33554432";
      "net.ipv4.tcp_wmem" = "4096 65536 33554432";
      "net.core.netdev_max_backlog" = 32768;
      "net.ipv4.tcp_max_syn_backlog" = 8192;

      "net.ipv4.tcp_slow_start_after_idle" = 0;
      "net.ipv4.tcp_fastopen" = 3;
      "net.ipv4.tcp_mtu_probing" = 1;
      "net.ipv4.tcp_tw_reuse" = 1;
      "net.ipv4.tcp_fin_timeout" = 30;
    };

    systemd.services.xray.serviceConfig.LimitNOFILE = 1048576;
  };
}
