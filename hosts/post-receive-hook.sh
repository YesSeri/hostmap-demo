set -e

repo_dir="$(pwd)"
homeDir="/var/lib/ci"
workdir="$homeDir/work"
pushlog="$homeDir/push.log"
joblogdir="$homeDir/jobs"

mkdir -p "$joblogdir"

log() {
  echo "$(date -Is) $*" >> "$pushlog"
}

while read -r oldrev newrev refname; do
  branch="${refname#refs/heads/}"
  joblog="$joblogdir/$newrev.log"

  log "queued commit=$newrev branch=$branch joblog=$joblog"

  (
    set -e

    if [ "$newrev" = "0000000000000000000000000000000000000000" ]; then
      log "deleted ref=$refname oldrev=$oldrev"
      exit 0
    fi

    rm -rf "$workdir"
    git --git-dir "$repo_dir" worktree prune
    git --git-dir "$repo_dir" worktree add --force "$workdir" "$newrev"

    cd "$workdir"

    now="$(date -u -Is)"

    payload="$(
      {
        nix eval --raw ".#nixosConfigurations.host1.config.system.build.toplevel.outPath"
        nix eval --raw ".#nixosConfigurations.host2.config.system.build.toplevel.outPath"
      } | jq -Rn \
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
      -o /dev/null \
      -H "Authorization: Api-Key demo" \
      -H 'content-type: application/json' \
      -d "$payload" \
      "http://10.0.2.2:8080/api/link/bulk"

    log "linked commit=$newrev branch=$branch count=2"
  ) >> "$joblog" 2>&1 < /dev/null &

done

echo "Queued hostmap linking job."
