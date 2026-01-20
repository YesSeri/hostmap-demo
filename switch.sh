
echo 'arg 1: ' $1
case "$1" in
    "server")
		system='hostmap-server'
		port=2221
		;;

    "host1")
		system='host1'
		port=2222
		;;
    "host2")
		system='host2'
		port=2223
		;;
    "ci")
		system='external-ci'
		port=2223
		;;

	*)
		echo "not a valid option"
		exit 1;
		;;
esac

attr=".#nixosConfigurations.${system}.config.system.build.toplevel"
export NIX_SSHOPTS="-p ${port}"
echo 'attr: ' $attr
echo 'opts: ' $NIX_SSHOPTS
# exit 0
storepath=$(nix build --no-link --print-out-paths ${attr})


nix copy --to ssh://root@localhost "$storepath"

ssh -p $port root@localhost "
  set -euo pipefail
  nix-env -p /nix/var/nix/profiles/system --set '$storepath'
  '$storepath'/bin/switch-to-configuration switch
"
