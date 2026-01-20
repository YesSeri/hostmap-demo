{ lib, pkgs, ... }:
{
  systemd.oomd.enable = false;

  users.users.root.initialPassword = "root";

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

  environment.systemPackages = with pkgs; [
    curl
    vim
    ripgrep
    fd
  ];

  system.stateVersion = "25.11";
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = false;
}
