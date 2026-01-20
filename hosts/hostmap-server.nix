{ pkgs, ... }:
let
  demoApiKey = "demo";
  apiKeyFile = toString (pkgs.writeText "hostmap-api-key.txt" demoApiKey);

  loggerPort = 9001;
in
{

  services.hostmap.server = {
    enable = true;
    port = 3000;
    repoUrl = "https://github.com/yesseri/hostmap-demo";
    groupingKey = "host_group_name";
    databaseUrl = "postgresql:///hostmap?user=hostmap&host=/run/postgresql";
    apiKeyFile = apiKeyFile;
    columns = [ "host_group_name" ];
    timeZone = "Europe/Copenhagen";
  };

  services.hostmap.scraper = {
    enable = true;
    activationLoggerPort = loggerPort;
    apiKeyFile = apiKeyFile;

    targetHosts = [
      {
        hostname = "host1";
        host_url = "127.0.0.2";
        metadata = {
          environment = "test";
          host_group_name = "hg-1";
        };
      }
      {
        hostname = "host2";
        host_url = "127.0.0.3";
        metadata = {
          environment = "test";
          host_group_name = "hg-1";
        };
      }
      {
        hostname = "hostmap-server";
        host_url = "127.0.0.4";
        metadata = {
          environment = "prod";
          host_group_name = "hostmap-group";
        };
      }
    ];
  };
}
