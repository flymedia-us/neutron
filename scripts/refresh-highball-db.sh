#!/bin/sh
# Refreshes the bundled snapshot of highball-db (CC0-1.0): game rows and game recipes at one
# commit, combined into third_party/highball-db/highball-db.json.
# Usage: scripts/refresh-highball-db.sh [commit]   (default: the head of main)
set -eu

repo="${HIGHBALL_DB_REPO:-https://github.com/gauthierpiarrette/highball-db.git}"
dest="$(cd "$(dirname "$0")/.." && pwd)/third_party/highball-db"
commit="${1:-main}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git -C "$work" init -q
git -C "$work" remote add origin "$repo"
git -C "$work" fetch -q --depth 1 origin "$commit"
git -C "$work" checkout -q FETCH_HEAD
sha=$(git -C "$work" rev-parse HEAD)
date=$(git -C "$work" log -1 --format=%cI)

# Only CC0 parts: db/derived (ODbL) and db/anticheat.json (MIT) stay out
python3 -I - "$work" "$sha" "$date" "$dest/highball-db.json" <<'PY'
import json, pathlib, sys
root, sha, date, out = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], pathlib.Path(sys.argv[4])
def read_source(path):
    if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()) or not path.is_file():
        sys.exit('refresh: refusing a source link or file outside the upstream checkout')
    return path.read_bytes()
games = [json.loads(read_source(p)) for p in sorted((root / "db/games").glob("*.json"))]
recipes = [json.loads(read_source(p)) for p in sorted((root / "recipes/games").glob("*.json"))]
license_text = read_source(root / 'LICENSE')
data = {"source": {"repository": "gauthierpiarrette/highball-db", "commit": sha, "date": date,
                   "license": "CC0-1.0"},
        "games": games, "recipes": recipes}
out.write_text(json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
(out.parent / 'LICENSE').write_bytes(license_text)
print(f"highball-db {sha[:12]} ({date}): {len(games)} games, {len(recipes)} recipes")
PY
