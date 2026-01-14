{ pkgs, ... }:
let
  demoApiKey = "demo";
  apiKeyFile = toString (pkgs.writeText "hostmap-api-key.txt" demoApiKey);

  loggerPort = 9001;
in
{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."hostmap" = {
      listen = [ { addr = "0.0.0.0"; port = 80; } ];
      locations."/" = { proxyPass = "http://127.0.0.1:3000"; };
    };
  };

  services.hostmap.server = {
    enable = true;
    port = 3000;
    repoUrl = "https://example.invalid/commit";
    groupingKey = "host_group_name";
    databaseUrl = "postgresql:///hostmap?user=hostmap&host=/run/postgresql";
    apiKeyFile = apiKeyFile;
    columns = [ "host_group_name" ];
    timeZone = "Europe/Copenhagen";
  };

  services.hostmap.scraper = {
    enable = true;
    serverUrl = "http://127.0.0.1:3000";
    activationLoggerPort = loggerPort;
    apiKeyFile = apiKeyFile;

    targetHosts = [
      {
        hostname = "hostmap-host1";
        host_url = "192.168.200.11";
        metadata = { environment = "test"; host_group_name = "hg-1"; };
      }
      {
        hostname = "hostmap-host2";
        host_url = "192.168.200.12";
        metadata = { environment = "test"; host_group_name = "hg-1"; };
      }
    ];
  };
}

