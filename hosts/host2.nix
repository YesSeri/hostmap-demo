{ ... }:
{
  services.hostmap.activationLogger = {
    enable = true;
    port = 9001;
  };
  environment.etc."hostmap-demo-message.txt".text = "host2 changed the demo message again";
}
