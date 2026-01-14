{ ... }:
{
  networking.hostName = "hostmap-server";
  networking.useDHCP = false;

  networking.interfaces.eth0.ipv4.addresses = [
    { address = "192.168.200.10"; prefixLength = 24; }
  ];

  virtualisation.qemu.networkingOptions = [
    "-netdev" "socket,id=net0,mcast=230.0.0.1:12345"
    "-device" "virtio-net-pci,netdev=net0,mac=52:54:00:00:00:10"
  ];

  virtualisation.forwardPorts = [
    { from = "host"; host.port = 8080; guest.port = 80; }
    { from = "host"; host.port = 2221; guest.port = 22; }
  ];

  virtualisation.vmVariant.virtualisation.cores = 2;
  virtualisation.vmVariant.virtualisation.memorySize = 2048;
}

