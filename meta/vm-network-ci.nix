{ ... }:
{
  networking.hostName = "external-ci";

  virtualisation.forwardPorts = [
    {
      from = "host";
      host.port = 2224;
      guest.port = 22;
    }
    {
      from = "host";
      host.port = 3001;
      guest.port = 3000;
    }
  ];

  virtualisation.memorySize = 4096;
  virtualisation.cores = 2;
}
