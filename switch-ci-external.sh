storepath=$(nix build --no-link --print-out-paths .#nixosConfigurations.external-ci.config.system.build.toplevel)

export NIX_SSHOPTS="-p 2224"
nix copy --to ssh://root@localhost "$storepath"

ssh $NIX_SSHOPTS  root@localhost "
  set -euo pipefail
  nix-env -p /nix/var/nix/profiles/system --set '$storepath'
  '$storepath'/bin/switch-to-configuration switch
"

