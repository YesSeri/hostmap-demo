#!/usr/bin/env bash
set -euo pipefail

case "$1" in
    "server")
		target='hostmap-server'
		port=2221
		;;

    "host1")
		target='host1'
		port=2222
		;;
    "host2")
		target='host2'
		port=2223
		;;

	*)
		echo "not a valid option"
		echo "usage: ./switch.sh <server|host1|host2>"
		exit 1;
		;;
esac

attr=".#nixosConfigurations.${target}.config.system.build.toplevel"
storepath=$(nix build --no-link --print-out-paths ${attr})

export NIX_SSHOPTS="-p ${port} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ./test-key"

nix copy --to ssh://root@localhost "$storepath"

ssh $NIX_SSHOPTS root@localhost "nix-env -p /nix/var/nix/profiles/system --set '$storepath' && '$storepath'/bin/switch-to-configuration switch"
