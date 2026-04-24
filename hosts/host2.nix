{ ... }:
{
  services.hostmap.activationLogger = {
    enable = true;
    port = 9001;
  };
  environment.etc."hostmap-change-demo.txt".text = "host 2 has changed!!";
}
