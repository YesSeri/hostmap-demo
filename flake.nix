{
  description = "Hostmap demo fleet";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    hostmap.url = "github:YesSeri/hostmap/simplifying-flake";
    hostmap.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      hostmap,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ hostmap.overlay ];
      };
      lib = nixpkgs.lib;
    in
    {
      nixosConfigurations.hostmap-server = lib.nixosSystem {
        inherit system pkgs;
        modules = [
          (import (nixpkgs + "/nixos/modules/virtualisation/qemu-vm.nix"))

          ./meta/vm-base.nix
          ./meta/vm-network-server.nix

          ./hosts/common.nix
          hostmap.nixosModules.hostmap
          ./hosts/hostmap-server.nix
        ];
      };

      nixosConfigurations.host1 = lib.nixosSystem {
        inherit system pkgs;
        modules = [
          (import (nixpkgs + "/nixos/modules/virtualisation/qemu-vm.nix"))

          ./meta/vm-base.nix
          ./meta/vm-network-host1.nix

          ./hosts/common.nix
          hostmap.nixosModules.hostmap
          ./hosts/host1.nix
        ];
      };

      nixosConfigurations.host2 = lib.nixosSystem {
        inherit system pkgs;
        modules = [
          (import (nixpkgs + "/nixos/modules/virtualisation/qemu-vm.nix"))

          ./meta/vm-base.nix
          ./meta/vm-network-host2.nix

          ./hosts/common.nix
          hostmap.nixosModules.hostmap
          ./hosts/host2.nix
        ];
      };
      nixosConfigurations.external-ci = lib.nixosSystem {
        inherit system pkgs;
        modules = [
          (import (nixpkgs + "/nixos/modules/virtualisation/qemu-vm.nix"))

          ./meta/vm-base.nix
          ./meta/vm-network-ci.nix

          ./hosts/common.nix
          hostmap.nixosModules.hostmap
          ./hosts/external-ci.nix
        ];
      };

      apps.${system} = {
        fleet-up = {
          type = "app";
          program = toString (
            pkgs.writeShellScript "fleet-up" ''
set -euo pipefail

if [ -d .fleet-state ]; then
echo "Fleet already running. Stop first: nix run .#fleet-down"
exit 1
fi

mkdir -p .fleet-build
mkdir -p .fleet-state/{pids,logs,qcow2}

echo "=== Build VMs ==="
nix build .#nixosConfigurations.hostmap-server.config.system.build.vm --out-link .fleet-build/hostmap-server
nix build .#nixosConfigurations.host1.config.system.build.vm          --out-link .fleet-build/host1
nix build .#nixosConfigurations.host2.config.system.build.vm          --out-link .fleet-build/host2
nix build .#nixosConfigurations.external-ci.config.system.build.vm    --out-link .fleet-build/external-ci

start_vm () {
local name="$1"
local vm_script="$2"
vm_script="$(realpath "$vm_script")"

echo "=== Start $name ==="

# Run the VM script with CWD set to qcow2 dir, so disk images land there.
(
  cd .fleet-state/qcow2
  QEMU_OPTS="-nographic" "$vm_script" > "../logs/$name.log" 2>&1 &
  echo $! > "../pids/$name.pid"
)
}
start_vm hostmap-server .fleet-build/hostmap-server/bin/*vm
start_vm host1          .fleet-build/host1/bin/*vm
start_vm host2          .fleet-build/host2/bin/*vm
start_vm external-ci    .fleet-build/external-ci/bin/*vm

echo
echo "UI (from desktop): http://localhost:8080"
echo "Server:    ssh root@localhost -p 2221   (password: root)"
echo "Host 1:    ssh root@localhost -p 2222   (password: root)"
echo "Host 2:    ssh root@localhost -p 2223   (password: root)"
echo "CI server: ssh root@localhost -p 2224   (password: root)"
echo "Disks: .fleet-state/qcow2/"
echo "Logs:  .fleet-state/logs/"
            ''
          );
        };
        fleet-down = {
          type = "app";
          program = toString (
            pkgs.writeShellScript "fleet-down" ''
set -euo pipefail
echo "Stopping fleet..."

kill_one () {
local name="$1"
local pidfile=".fleet-state/pids/$name.pid"

if [ -f "$pidfile" ]; then
  pid="$(cat "$pidfile")"
  if kill -0 "$pid" 2>/dev/null; then
	kill "$pid" 2>/dev/null || true
	# reap it so it doesn't linger as a zombie
	wait "$pid" 2>/dev/null || true
  fi
fi
}

kill_one host1
kill_one host2
kill_one external-ci
kill_one hostmap-server

rm -rf .fleet-state
echo "Fleet stopped."
            ''
          );
        };
      };
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    };
}
