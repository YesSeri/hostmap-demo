set -euo pipefail


attrs=(
  "nixosConfigurations.host1.config.system.build.toplevel"
  "nixosConfigurations.host2.config.system.build.toplevel"
  "nixosConfigurations.hostmap-server.config.system.build.toplevel"
)
build_payload() {
  local commit_hash="$1"
  local branch="$2"
  local created_at="$3"

  local first=true

  echo "["

  for attr in "${attrs[@]}"; do
	nix eval --raw ".#${attr}.outPath"

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
}

homeDir="/var/lib/ci"
repo_dir="$(pwd)"
workdir="${homeDir}/work"
pushlog="${homeDir}/push.log"

hostmap_url="http://10.0.2.2:8080/api/link/bulk"
auth_header="Authorization: Api-Key demo"


while read -r oldrev newrev refname; do
  branch="${refname#refs/heads/}"

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

  payload=`build_payload "$newrev" "$branch" "$now"`

  curl -fsS \
       -H "$auth_header" \
       -H 'content-type: application/json' \
       -d "$payload" \
       "$hostmap_url"

  echo "$(date -Is) linked commit=$newrev branch=$branch count=${#attrs[@]}" >> "$pushlog"
done
