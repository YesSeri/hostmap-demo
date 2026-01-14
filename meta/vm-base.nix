{ lib, ... }:
{
  systemd.oomd.enable = false;
  virtualisation.qemu.options = [ "-nic" "none" ];
}

