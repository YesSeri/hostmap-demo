storepath=$(nix build --no-link --print-out-paths .#nixosConfigurations.host1.config.system.build.toplevel)

export NIX_SSHOPTS="-p 2222"
nix copy --to ssh://root@localhost "$storepath"

ssh -p 2222 root@localhost "
  set -euo pipefail
  nix-env -p /nix/var/nix/profiles/system --set '$storepath'
  '$storepath'/bin/switch-to-configuration switch
"

