{ lib, pkgs, ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
      UsePAM = true;
    };
  };

  users.users.root.initialPassword = "root";
  services.getty.autologinUser = lib.mkForce null;

  environment.systemPackages = with pkgs; [ curl jq vim git ];

  system.stateVersion = "25.11";
}

