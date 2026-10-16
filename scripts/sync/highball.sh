#!/bin/sh
# shellcheck disable=SC2016
# Bumps the HighballKit pin to Highball's latest release and refreshes the highball-db snapshot,
# in one PR when both changed. Treats upstream files as data: never runs package manifests.
# Usage: scripts/sync/highball.sh
set -eu
cd "$(dirname "$0")/../.."
# shellcheck source=scripts/sync/common.sh disable=SC1091
. scripts/sync/common.sh

REFRESH_DB="${REFRESH_DB:-scripts/refresh-highball-db.sh}"

tag=$("$GH" release list -R gauthierpiarrette/highball --exclude-pre-releases --limit 1 --json tagName -q '.[0].tagName')
latest=${tag#v}
[ -z "$latest" ] || printf '%s\n' "$latest" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' \
  || { echo 'sync: refusing an unexpected Highball release tag' >&2; exit 1; }
pinned=$(sed -n 's/.*gauthierpiarrette\/highball", exact: "\([^"]*\)".*/\1/p' app/Package.swift)
[ -n "$pinned" ] || { echo "sync: no HighballKit pin found in app/Package.swift" >&2; exit 1; }
newer_kit=""
if [ -n "$latest" ] && [ "$latest" != "$pinned" ] && [ "$(printf '%s\n%s\n' "$pinned" "$latest" | sort -V | tail -1)" = "$latest" ]; then
  newer_kit="$latest"
fi

db_head=$("$GH" api repos/gauthierpiarrette/highball-db/commits/main -q .sha)
db_pinned=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["source"]["commit"])' third_party/highball-db/highball-db.json)
newer_db=""
[ -n "$db_head" ] && [ "$db_head" != "$db_pinned" ] && newer_db="$db_head"

if [ -z "$newer_kit" ] && [ -z "$newer_db" ]; then
  sync_log "highball: HighballKit $pinned and highball-db $(printf %.7s "$db_pinned") are current"
  exit 0
fi

branch="sync/highball"
[ -z "$newer_kit" ] || branch="$branch-$newer_kit"
[ -z "$newer_db" ] || branch="$branch-db-$(printf %.7s "$newer_db")"
if branch_exists "$branch" || pr_exists "$branch"; then
  sync_log "highball: $branch already has a PR"
  exit 0
fi

git fetch -q origin main
git_identity
git checkout -q -B "$branch" origin/main
notes=""
if [ -n "$newer_kit" ]; then
  # Resolve a lightweight or annotated tag to a commit through GitHub's data API.
  # SwiftPM will validate the graph in read-only CI, without this job's write token.
  object=$("$GH" api "repos/gauthierpiarrette/highball/git/ref/tags/$tag" -q '.object | .type + " " + .sha')
  depth=0
  while :; do
    kind=${object%% *}; revision=${object#* }
    case "$revision" in ''|*[!a-f0-9]*) echo 'sync: invalid package revision' >&2; exit 1 ;; esac
    [ "${#revision}" -eq 40 ] || { echo 'sync: invalid package revision length' >&2; exit 1; }
    [ "$kind" != commit ] || break
    [ "$kind" = tag ] && [ "$depth" -lt 4 ] || { echo 'sync: release does not resolve to a commit' >&2; exit 1; }
    depth=$((depth + 1))
    object=$("$GH" api "repos/gauthierpiarrette/highball/git/tags/$revision" -q '.object | .type + " " + .sha')
  done
  sed -i.bak "s/gauthierpiarrette\/highball\", exact: \"$pinned\"/gauthierpiarrette\/highball\", exact: \"$newer_kit\"/" app/Package.swift
  sed -i.bak "s/highballKitVersion = \"$pinned\"/highballKitVersion = \"$newer_kit\"/" app/Sources/HighballEnvCore/HighballEnvCore.swift
  rm -f app/Package.swift.bak app/Sources/HighballEnvCore/HighballEnvCore.swift.bak
  python3 -I - "$newer_kit" "$revision" <<'PY'
import json, pathlib, sys
path = pathlib.Path('app/Package.resolved')
data = json.loads(path.read_text())
pins = [p for p in data['pins'] if p['identity'] == 'highball']
if len(pins) != 1 or pins[0]['location'].removesuffix('.git') != 'https://github.com/gauthierpiarrette/highball':
    sys.exit('sync: unexpected Highball dependency identity')
pins[0]['state'] = {'version': sys.argv[1], 'revision': sys.argv[2]}
# A manifest change invalidates SwiftPM's originHash. Let read-only CI regenerate it.
data.pop('originHash', None)
path.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')
PY
  git add app/Package.swift app/Package.resolved app/Sources/HighballEnvCore/HighballEnvCore.swift
  notes="$notes- HighballKit $pinned → $newer_kit: https://github.com/gauthierpiarrette/highball/releases/tag/v$newer_kit
"
fi
if [ -n "$newer_db" ]; then
  "$REFRESH_DB" "$newer_db" >/dev/null
  git add third_party/highball-db
  notes="$notes- highball-db $(printf %.7s "$db_pinned") → $(printf %.7s "$newer_db"): https://github.com/gauthierpiarrette/highball-db/compare/$db_pinned...$newer_db
"
fi
git commit -q -m "Sync Highball: ${newer_kit:+HighballKit $newer_kit}${newer_kit:+${newer_db:+, }}${newer_db:+highball-db $(printf %.7s "$newer_db")}

$notes"
git push -q -u origin "$branch"
open_review "$branch" highball "sync: Highball ${newer_kit:+$newer_kit }${newer_db:+db $(printf %.7s "$newer_db")}" \
  "$(printf '## What\n%s\n## Before merging\n- CI green: a HighballKit bump can change the API `highball-env` builds against.\n- Read the Highball release notes for engine changes that need a new `SupportedRunner` entry.\n- Add a dated line under "Changes from upstream" in README.md.\n%s' "$notes" "$(footer)")"
sync_log "highball: prepared $branch for review"

[ -z "${GITHUB_OUTPUT:-}" ] || printf 'branch=%s\n' "$branch" >> "$GITHUB_OUTPUT"
