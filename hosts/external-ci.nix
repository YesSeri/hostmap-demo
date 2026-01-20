{ pkgs, ... }:
let
  demoApiKey = "demo";
  apiKeyFile = toString (pkgs.writeText "hostmap-api-key.txt" demoApiKey);
  homeDir = "/var/lib/ci";
  repoDir = "${homeDir}/hostmap-demo.git";
  postReceiveHook = pkgs.writeShellScript "post-receive" ''
set -euo pipefail

repo_dir="$(pwd)"
workdir="${homeDir}/work"
pushlog="${homeDir}/push.log"

hostmap_url="http://10.0.2.2:8080/api/link/bulk"
auth_header="Authorization: Api-Key demo"

attrs=(
  "nixosConfigurations.host1.config.system.build.toplevel"
  "nixosConfigurations.host2.config.system.build.toplevel"
)

while read -r oldrev newrev refname; do
  branch="''${refname#refs/heads/}"

  if [ "$newrev" = "0000000000000000000000000000000000000000" ]; then
	echo "$(date -Is) deleted ref=$refname oldrev=$oldrev" >> "$pushlog"
	continue
  fi

  rm -rf "$workdir"
  git --git-dir "$repo_dir" worktree prune >/dev/null 2>&1 || true
  git --git-dir "$repo_dir" worktree add --force "$workdir" "$newrev" >/dev/null

  cd "$workdir"
  [ -f flake.nix ] || { echo "flake.nix missing" >&2; exit 2; }

  now="$(date -u -Is)"

  payload="$(
	for attr in "''${attrs[@]}"; do
	  path="$(nix eval --raw ".#''${attr}.outPath")"
	  printf '%s\n' "$path"
	done | jq -Rn \
	  --arg commit_hash "$newrev" \
	  --arg branch "$branch" \
	  --arg created_at "$now" \
	  '[ inputs
		 | select(length > 0)
		 | {
			 store_path: .,
			 commit_hash: $commit_hash,
			 branch: $branch,
			 created_at: $created_at
		   }
	   ]'
  )"

  curl -fsS \
	-H "$auth_header" \
	-H 'content-type: application/json' \
	-d "$payload" \
	"$hostmap_url"

  echo "$(date -Is) linked commit=$newrev branch=$branch count=''${#attrs[@]}" >> "$pushlog"
done
  '';

in
{
  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  environment.systemPackages = with pkgs; [
    git
    curl
    jq
    nix
  ];
  users.groups.ci = { };

  users.users.ci = {
    isNormalUser = true;
    home = homeDir;
    createHome = true;
    extraGroups = [ "wheel" ];
    initialPassword = "password";
  };

  systemd.services.init-ci-repo = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "ci";
      Group = "ci";
    };

    script = ''
      	  set -euo pipefail

      	  mkdir -p ${homeDir}

      	  if [ ! -f ${repoDir}/HEAD ]; then
      	    rm -rf ${repoDir}
      		mkdir -p ${repoDir}
      		${pkgs.git}/bin/git init --bare ${repoDir}
      	  fi
      	  mkdir -p ${repoDir}/hooks
      	  install -m 0755 ${postReceiveHook} ${repoDir}/hooks/post-receive
    '';
  };
}
