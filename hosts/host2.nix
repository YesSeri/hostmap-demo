{ ... }:
{
  services.hostmap.activationLogger = {
    enable = true;
    port = 9001;
  };
  environment.etc."hostmap-demo-message.txt".text = "hello world from host2";
}
