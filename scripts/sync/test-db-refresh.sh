#!/bin/sh
# Offline regression: never publish runner files through an upstream data symlink.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/fork/scripts" "$work/fork/third_party/highball-db" "$work/source/db/games" "$work/source/recipes/games"
cp "$here/refresh-highball-db.sh" "$work/fork/scripts/"
git -C "$work/source" init -q
git -C "$work/source" config user.name test
git -C "$work/source" config user.email test@example.invalid
printf '{"appid":1}\n' > "$work/source/db/games/game.json"
printf '{"id":"fixture"}\n' > "$work/source/recipes/games/recipe.json"
printf 'CC0 fixture\n' > "$work/source/LICENSE"
printf '{"outside":"must stay private"}\n' > "$work/private.json"
commit() { git -C "$work/source" add -A; git -C "$work/source" commit -qm "$1"; }
refresh() {
  HIGHBALL_DB_REPO="$work/source" sh "$work/fork/scripts/refresh-highball-db.sh" HEAD > "$work/log" 2>&1
}
commit valid
refresh
cmp "$work/source/LICENSE" "$work/fork/third_party/highball-db/LICENSE"
cp "$work/fork/third_party/highball-db/highball-db.json" "$work/before.json"

rm "$work/source/LICENSE"
ln -s "$work/private.json" "$work/source/LICENSE"
commit license-link
if refresh; then echo 'FAIL: accepted a symlinked license' >&2; exit 1; fi
cmp "$work/before.json" "$work/fork/third_party/highball-db/highball-db.json"
printf 'CC0 fixture\n' > "$work/expected-license"
cmp "$work/expected-license" "$work/fork/third_party/highball-db/LICENSE"

rm "$work/source/LICENSE" "$work/source/db/games/game.json"
printf 'CC0 fixture\n' > "$work/source/LICENSE"
ln -s "$work/private.json" "$work/source/db/games/game.json"
commit data-link
if refresh; then echo 'FAIL: accepted a symlinked game row' >&2; exit 1; fi
cmp "$work/before.json" "$work/fork/third_party/highball-db/highball-db.json"
rm "$work/source/db/games/game.json"
rmdir "$work/source/db/games"
mkdir "$work/outside"
cp "$work/private.json" "$work/outside/game.json"
ln -s "$work/outside" "$work/source/db/games"
commit directory-link
if refresh; then echo 'FAIL: accepted a directory escaping the source tree' >&2; exit 1; fi
cmp "$work/before.json" "$work/fork/third_party/highball-db/highball-db.json"
echo '==> database refresh: valid data copied, hostile license/data links refused without publishing outside files'
