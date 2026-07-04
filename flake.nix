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
	   linkCurrentCommit = pkgs.writeShellScript "link-current-commit" ''
    set -euo pipefail

    repo_root="$(git rev-parse --show-toplevel)"
    cd "$repo_root"

    commit_hash="$(git rev-parse HEAD)"
    branch="$(git branch --show-current)"
    created_at="$(date -u -Is)"

    echo "=== Link current commit to store paths ==="
    echo "commit: $commit_hash"
    echo "branch:  $branch"

    attrs=(
      "nixosConfigurations.host1.config.system.build.toplevel"
      "nixosConfigurations.host2.config.system.build.toplevel"
      "nixosConfigurations.hostmap-server.config.system.build.toplevel"
    )

    first=true

    payload="$(
      echo "["

      for attr in "''${attrs[@]}"; do
        store_path="$(nix eval --raw ".#''${attr}.outPath")"

        if [ "$first" = true ]; then
          first=false
        else
          echo ","
        fi

        cat <<EOF
  {
    "store_path": "$store_path",
    "commit_hash": "$commit_hash",
    "branch": "$branch",
    "created_at": "$created_at"
  }
EOF
      done

      echo "]"
    )"

    ${pkgs.curl}/bin/curl -fsS \
      -H "Authorization: Api-Key demo" \
      -H "content-type: application/json" \
      -d "$payload" \
      "http://localhost:8080/api/link/bulk"

    echo
    echo "Linked current commit to Hostmap."
  '';
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

      devShells.${system}.default = pkgs.mkShell {
        shellHook = ''
          			export DEMO_SSH_OPTS="-i ./test-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes"
          			echo 'demo SSH options are available at $DEMO_SSH_OPTS'
          		  '';
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

              cat <<'EOF'
              Web site for overview of hosts is at http://localhost:8080
              Run nix develop and then use the following to access servers
              Server:    ssh root@localhost -p 2221 $DEMO_SSH_OPTS
              Host 1:    ssh root@localhost -p 2222 $DEMO_SSH_OPTS
              Host 2:    ssh root@localhost -p 2223 $DEMO_SSH_OPTS
              CI server: your computer is acting as CI server for this demo
              EOF
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
              kill_one hostmap-server

              rm -rf .fleet-state
              echo "Fleet stopped."
            ''
          );
        };

		link-current-commit = {
          type = "app";
          program = toString linkCurrentCommit;
        };

        demo = {
          type = "app";
          program = toString (
            pkgs.writeShellScript "demo" ''
                          set -euo pipefail

                          wait_for_port () {
                            host="$1"
                            port="$2"

                            echo "=== Waiting for $host:$port ==="

                            for i in $(seq 1 120); do
                              if timeout 1 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
                                echo "=== $host:$port is ready ==="
                                return 0
                              fi

                              sleep 1
                            done

                            echo "Timed out waiting for $host:$port"
                            exit 1
                          }


                          commit_all () {
                            msg="$1"

                            git add hosts/host1.nix hosts/host2.nix

                            git -c user.name="Hostmap Demo" \
                                -c user.email="demo@example.invalid" \
                                commit -m "$msg"
                          }

                          set_host1_port () {
                            port="$1"

                            sed -i -E "s#^([[:space:]]*networking\.firewall\.allowedTCPPorts = \[ )[0-9]+( \];)#\1$port\2#" hosts/host1.nix

                            if git diff --quiet -- hosts/host1.nix; then
                              echo "Failed to change host1 port. Expected line like:"
                              echo '  networking.firewall.allowedTCPPorts = [ 8080 ];'
                              exit 1
                            fi
                          }

                          set_host2_message () {
                            message="$1"

                            sed -i -E "s#^([[:space:]]*environment\.etc\.\"hostmap-demo-message\.txt\"\.text = \")[^\"]*(\";)#\1$message\2#" hosts/host2.nix

                            if git diff --quiet -- hosts/host2.nix; then
                              echo "Failed to change host2 message. Expected line like:"
                              echo '  environment.etc."hostmap-demo-message.txt".text = "hello world from host2";'
                              exit 1
                            fi
                          }

                          repo_root="$(git rev-parse --show-toplevel)"
                          cd "$repo_root"

                          if [ -n "$(git status --porcelain)" ]; then
                            echo "Working tree is not clean."
                            echo "Commit or stash your changes before running the demo."
                            exit 1
                          fi

                          if [ ! -d .fleet-state ]; then
                            echo "=== Starting demo fleet ==="
                            nix run .#fleet-up
                          else
                            echo "=== Fleet already running ==="
                          fi

                          wait_for_port localhost 8080

                          echo "=== Commit A: current state ==="
                          ${linkCurrentCommit}

                          echo "=== Activate host1 and host2 ==="
                          ./switch.sh host1
                          ./switch.sh host2
                          ./switch.sh server

                          echo "=== Commit B: host1 opens TCP port 8081 ==="
                          set_host1_port 8081
                          commit_all "Demo: open TCP port 8081 on host1"
                          ${linkCurrentCommit}
                          ./switch.sh host1

                          echo "=== Commit C: host1 changes open TCP port to 8082 ==="
                          set_host1_port 8082
                          commit_all "Demo: change host1 open TCP port to 8082"
                          ${linkCurrentCommit}
                          ./switch.sh host1

                          echo "=== Commit D: host2 changes the /etc demo file ==="
                          set_host2_message "hello from host2 demo commit"
                          commit_all "Demo: change /etc demo file on host2"
                          ${linkCurrentCommit}
                          ./switch.sh host2

                          echo "=== Commit E: host2 changes the /etc demo file again ==="
                          set_host2_message "host2 changed the demo message again"
                          commit_all "Demo: change /etc demo file on host2 again"
                          ${linkCurrentCommit}
                          ./switch.sh host2

                          echo
                          echo "Demo ready."
                          echo "Open: http://localhost:8080"
                          echo
                          echo "Expected result:"
                          echo "- host1 has historical activations for the port changes"
                          echo "- host2 has historical activations for the /etc file changes"
                          echo "- the Hostmap UI can link the activated system images to Git commits"
            ''
          );
        };

      };
    };
}
