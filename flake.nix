{
  description = "Hostmap demo fleet (explicit + beginner friendly)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    hostmap.url = "github:YesSeri/hostmap/simplifying-flake";
    hostmap.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, hostmap }:
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

      nixosConfigurations.hostmap-host1 = lib.nixosSystem {
        inherit system pkgs;
        modules = [
          (import (nixpkgs + "/nixos/modules/virtualisation/qemu-vm.nix"))

          ./meta/vm-base.nix
          ./meta/vm-network-host1.nix

          ./hosts/common.nix
          hostmap.nixosModules.hostmap
          ./hosts/hostmap-host1.nix
        ];
      };

      nixosConfigurations.hostmap-host2 = lib.nixosSystem {
        inherit system pkgs;
        modules = [
          (import (nixpkgs + "/nixos/modules/virtualisation/qemu-vm.nix"))

          ./meta/vm-base.nix
          ./meta/vm-network-host2.nix

          ./hosts/common.nix
          hostmap.nixosModules.hostmap
          ./hosts/hostmap-host2.nix
        ];
      };

      apps.${system} = {
        fleet-up = {
        type = "app";
        program = toString (pkgs.writeShellScript "fleet-up" ''
          set -euo pipefail

          if [ -d .fleet-pids ]; then
            echo "Fleet already running. Stop first: nix run .#fleet-down"
            exit 1
          fi

          mkdir -p .fleet-pids .fleet-build

          echo "=== Build VMs ==="
          nix build .#nixosConfigurations.hostmap-server.config.system.build.vm --out-link .fleet-build/hostmap-server
          nix build .#nixosConfigurations.hostmap-host1.config.system.build.vm  --out-link .fleet-build/hostmap-host1
          nix build .#nixosConfigurations.hostmap-host2.config.system.build.vm  --out-link .fleet-build/hostmap-host2

          echo "=== Start hostmap-server ==="
          QEMU_OPTS="-nographic" .fleet-build/hostmap-server/bin/*vm > .fleet-pids/server.log 2>&1 &
          echo $! > .fleet-pids/server.pid

          echo "=== Start host1 ==="
          QEMU_OPTS="-nographic" .fleet-build/hostmap-host1/bin/*vm > .fleet-pids/host1.log 2>&1 &
          echo $! > .fleet-pids/host1.pid

          echo "=== Start host2 ==="
          QEMU_OPTS="-nographic" .fleet-build/hostmap-host2/bin/*vm > .fleet-pids/host2.log 2>&1 &
          echo $! > .fleet-pids/host2.pid

          echo
          echo "Fleet started"
          echo "UI:  http://localhost:8080"
          echo "SSH: ssh root@localhost -p 2221   (password: root)"
        '');
		};
        fleet-down = {
        type = "app";
        program = toString (pkgs.writeShellScript "fleet-down" ''
          set -euo pipefail
          echo "Stopping fleet..."

          [ -f .fleet-pids/server.pid ] && kill "$(cat .fleet-pids/server.pid)" || true
          [ -f .fleet-pids/host1.pid ] && kill "$(cat .fleet-pids/host1.pid)" || true
          [ -f .fleet-pids/host2.pid ] && kill "$(cat .fleet-pids/host2.pid)" || true

          rm -rf .fleet-pids
          echo "Fleet stopped."
        '');
		};
      };
    };
}

