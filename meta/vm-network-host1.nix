{ ... }:
{
  networking.hostName = "host1";

  virtualisation.forwardPorts = [
    {
      from = "host";
      host.port = 2222;
      guest.port = 22;
    }
    {
      from = "host";
      host.port = 9001;
      guest.port = 9001;
    }
  ];

  virtualisation.vmVariant.virtualisation.cores = 1;
  virtualisation.vmVariant.virtualisation.memorySize = 1024;
}
