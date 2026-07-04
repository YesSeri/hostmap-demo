{ ... }:
{
  services.hostmap.activationLogger = {
    enable = true;
    port = 9001;
  };
  networking.firewall.allowedTCPPorts = [ 8082 ];
}
