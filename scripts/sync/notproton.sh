#!/bin/sh
# shellcheck disable=SC2016
# Merges NotProton's main into a branch and opens a PR, or an issue when the merge conflicts.
# Usage: scripts/sync/notproton.sh   (run from any directory of the checkout)
set -eu
cd "$(dirname "$0")/../.."
# shellcheck source=scripts/sync/common.sh disable=SC1091
. scripts/sync/common.sh

UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/NotProtonNot/NotProton.git}"
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git fetch -q upstream main
git fetch -q origin main

pinned=$(git show origin/main:UPSTREAMS.json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["primary"]["commit"])' 2>/dev/null) || pinned=""
if [ -n "$pinned" ] && [ "$(git rev-parse "$pinned^{commit}" 2>/dev/null)" = "$(git rev-parse upstream/main)" ]; then
  sync_log "notproton: origin/main already records upstream/main as integrated"
  exit 0
fi

if git merge-base --is-ancestor upstream/main origin/main; then
  sync_log "notproton: origin/main already has upstream/main"
  exit 0
fi

sha=$(git rev-parse --short=7 upstream/main)
branch="sync/notproton-$sha"
if branch_exists "$branch" || pr_exists "$branch" || issue_exists "NotProton $sha"; then
  sync_log "notproton: $sha is already in a PR or issue"
  exit 0
fi

commits=$(git log --oneline origin/main..upstream/main)
git_identity
git checkout -q -B "$branch" origin/main
if git merge --no-ff --no-commit upstream/main >/dev/null 2>&1 || git rev-parse -q --verify MERGE_HEAD >/dev/null; then
  # Neutron release versions have their own lifecycle.
  if git cat-file -e origin/main:dylib/version.h 2>/dev/null; then
    git restore --source=origin/main --staged --worktree -- dylib/version.h
  fi
else
  echo 'sync: could not start the NotProton merge' >&2
  exit 1
fi

conflicts=$(git diff --name-only --diff-filter=U)
if [ -z "$conflicts" ]; then
  if [ -f UPSTREAMS.json ]; then
    upstream_commit=$(git rev-parse upstream/main)
    upstream_version=$(git show upstream/main:dylib/version.h | sed -n 's/^#define NOTPROTON_VERSION "\([^"]*\)"$/\1/p')
    python3 -I - "$upstream_commit" "$upstream_version" <<'PY'
import json, pathlib, sys
path = pathlib.Path('UPSTREAMS.json')
upstreams = json.loads(path.read_text())
upstreams['primary'].update(commit=sys.argv[1], version=sys.argv[2])
path.write_text(json.dumps(upstreams, indent=2) + '\n')
PY
    git add UPSTREAMS.json
  fi
  git commit -q -m "Merge NotProton $sha"
  git push -q -u origin "$branch"
  open_review "$branch" notproton "sync: merge NotProton $sha" \
    "$(printf '## What\nMerges upstream NotProton `%s` into main. Clean merge.\n\n## Upstream commits\n```\n%s\n```\n\n## Before merging\n- CI must be green, including `brandcheck`.\n- Add a dated entry to CHANGELOG.md if the change is user-visible.\n%s' "$sha" "$commits" "$(footer)")"
  [ -z "${GITHUB_OUTPUT:-}" ] || printf 'branch=%s\n' "$branch" >> "$GITHUB_OUTPUT"
  sync_log "notproton: prepared $sha for review"
else
  git merge --abort
  git checkout -q origin/main
  git branch -q -D "$branch"
  notice=$(mktemp)
  trap 'rm -f "$notice"' EXIT
  printf 'NotProton %s needs a manual merge.\n\n## Conflicts\n```\n%s\n```\n\n## Upstream commits\n```\n%s\n```\n\nMerge `upstream/main` by hand on a branch and open a PR.%s' \
    "$sha" "$conflicts" "$commits" "$(footer)" > "$notice"
  sync_issue notproton 'Upstream sync: NotProton merge conflict' "$notice"
  sync_log "notproton: $sha conflicts, recorded a review issue"
fi
