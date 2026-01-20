{ ... }:
{
  networking.hostName = "host2";

  virtualisation.forwardPorts = [
    {
      from = "host";
      host.port = 2223;
      guest.port = 22;
    }
    {
      from = "host";
      host.port = 9002;
      guest.port = 9001;
    }
  ];

  virtualisation.vmVariant.virtualisation.cores = 1;
  virtualisation.vmVariant.virtualisation.memorySize = 1024;
}
