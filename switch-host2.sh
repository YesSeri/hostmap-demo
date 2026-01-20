storepath=$(nix build --no-link --print-out-paths .#nixosConfigurations.hostmap-host2.config.system.build.toplevel)

export NIX_SSHOPTS="-p 2223"
nix copy --to ssh://root@localhost "$storepath"

ssh -p 2223 root@localhost "
  set -euo pipefail
  nix-env -p /nix/var/nix/profiles/system --set '$storepath'
  '$storepath'/bin/switch-to-configuration switch
"

