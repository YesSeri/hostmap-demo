{ lib, ... }:
let
  loggerPort = 9001;
in
{
  networking.hostName = "hostmap-server";

  virtualisation.forwardPorts = [
    {
      from = "host";
      host.port = 8080;
      guest.port = 80;
    }
    {
      from = "host";
      host.port = 2221;
      guest.port = 22;
    }
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."hostmap" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
      };
    };

    virtualHosts."activationlogger-host1" = {
      listen = [
        {
          addr = "127.0.0.2";
          port = loggerPort;
        }
      ];
      locations."/" = {
        proxyPass = "http://10.0.2.2:${toString loggerPort}";
      };
    };

    virtualHosts."activationlogger-host2" = {
      listen = [
        {
          addr = "127.0.0.3";
          port = loggerPort;
        }
      ];
      locations."/" = {
        proxyPass = "http://10.0.2.2:${toString (loggerPort + 1)}";
      };
    };
  };

  virtualisation.vmVariant.virtualisation.cores = 2;
  virtualisation.vmVariant.virtualisation.memorySize = 2048;
}
