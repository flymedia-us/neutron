#!/bin/sh
# Exercises the upstream sync scripts against fixture repositories and a stubbed gh.
# Usage: sh scripts/sync/test-sync.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0
ok() { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n         want [%s]\n         got  [%s]\n' "$1" "$2" "$3"; fails=$((fails + 1)); }
is() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi; }
has() { if grep -q -- "$2" "$3" 2>/dev/null; then ok "$1"; else bad "$1" "a line matching $2" "$(cat "$3" 2>/dev/null)"; fi; }
hasnt() { if grep -q -- "$2" "$3" 2>/dev/null; then bad "$1" "no line matching $2" "$(grep -- "$2" "$3")"; else ok "$1"; fi; }

# A gh that records every call and answers from files the cases write
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_LOG"
case "$1 $2" in
  "issue list") cat "$STUB_DIR/issues" 2>/dev/null ;;
  "pr list") cat "$STUB_DIR/prs" 2>/dev/null ;;
  "release list") cat "$STUB_DIR/releases" 2>/dev/null ;;
  "api repos/gauthierpiarrette/highball/git/ref/tags/"*)
    if [ -f "$STUB_DIR/annotated" ]; then printf 'tag %040d\n' 2; else printf 'commit %040d\n' 1; fi ;;
  "api repos/gauthierpiarrette/highball/git/tags/"*) printf 'commit %040d\n' 1 ;;
  "api repos/gauthierpiarrette/highball-db/commits/main") cat "$STUB_DIR/dbhead" 2>/dev/null ;;
  "pr create")
    if [ -f "$STUB_DIR/block-pr" ]; then echo 'Organization policy blocks PR creation' >&2; exit 1; fi
    echo "https://example.invalid/1" ;;
  "issue create")
    while [ "$#" -gt 0 ]; do
      if [ "$1" = --body-file ]; then cat "$2" >> "$STUB_LOG"; break; fi
      shift
    done
    echo "https://example.invalid/1" ;;
esac
STUB
chmod +x "$work/bin/gh"
export GH="$work/bin/gh" REPO="example/fork" STUB_DIR="$work/stub" STUB_LOG="$work/gh.log"
mkdir -p "$STUB_DIR"
git_quiet() { git -c user.name=t -c user.email=t@example.invalid -c init.defaultBranch=main "$@"; }

# A checkout with the sync scripts in it, an origin and an upstream to talk to
checkout() {
  rm -rf "$work/repo" "$work/origin.git" "$work/upstream.git" "$work/seed"
  git_quiet init -q "$work/seed"
  mkdir -p "$work/seed/scripts/sync"
  cp "$here"/common.sh "$here"/notproton.sh "$here"/highball.sh "$here"/highball-engine.sh "$here"/known-highball-engine "$work/seed/scripts/sync/"
  printf 'line one\nline two\n' > "$work/seed/steam.cpp"
  git_quiet -C "$work/seed" add -A && git_quiet -C "$work/seed" commit -q -m "base"
  git_quiet clone -q --bare "$work/seed" "$work/origin.git"
  git_quiet clone -q --bare "$work/seed" "$work/upstream.git"
  git_quiet clone -q "$work/origin.git" "$work/repo"
  git_quiet -C "$work/repo" remote add upstream "$work/upstream.git"
}
upstream_commit() {   # file content message
  rm -rf "$work/up"; git_quiet clone -q "$work/upstream.git" "$work/up"
  printf '%s' "$2" > "$work/up/$1"; git_quiet -C "$work/up" add -A; git_quiet -C "$work/up" commit -q -m "$3"; git_quiet -C "$work/up" push -q origin main
  git_quiet -C "$work/up" rev-parse --short=7 HEAD
}
origin_commit() {
  rm -rf "$work/or"; git_quiet clone -q "$work/origin.git" "$work/or"
  printf '%s' "$2" > "$work/or/$1"; git_quiet -C "$work/or" add -A; git_quiet -C "$work/or" commit -q -m "$3"; git_quiet -C "$work/or" push -q origin main
}
run() { : > "$STUB_LOG"; sh "$work/repo/scripts/sync/$1" > "$work/out" 2>&1 || echo "exit $?" >> "$work/out"; }

echo "== NotProton: nothing new =="
checkout
run notproton.sh
has "reports main already has upstream" "already has upstream/main" "$work/out"
hasnt "opens nothing" "create" "$STUB_LOG"

echo "== NotProton: a manually adapted source import is already current =="
checkout
sha=$(upstream_commit fix.c 'int fixed;' "Fix reviewed upstream")
full_sha=$(git -C "$work/upstream.git" rev-parse main)
origin_commit UPSTREAMS.json "$(printf '{"primary":{"commit":"%s"}}' "$full_sha")" "Record adapted upstream source"
run notproton.sh
has "source pin avoids proposing an already adapted import" "already records upstream/main" "$work/out"
hasnt "an integrated source pin opens nothing" "create" "$STUB_LOG"
checkout

echo "== NotProton: a clean merge becomes a PR =="
sha=$(upstream_commit fix.c 'int fixed;' "Fix output logging")
run notproton.sh
has "a PR is created from the sync branch" "pr create .* --head sync/notproton-$sha" "$STUB_LOG"
has "the PR carries the upstream-sync label" "--label upstream-sync --label notproton" "$STUB_LOG"
is "the branch is pushed to origin" "1" "$(git -C "$work/origin.git" branch --list "sync/notproton-$sha" | wc -l | tr -d ' ')"
is "the merge commit is the bot's" "Neutron sync" "$(git -C "$work/origin.git" log -1 --format=%an "sync/notproton-$sha")"
run notproton.sh
hasnt "a second run opens no second PR" "pr create" "$STUB_LOG"
has "and says why" "already in a PR or issue" "$work/out"

echo "== NotProton: PR policy leaves a review branch and issue =="
checkout
sha=$(upstream_commit fix.c 'int fixed;' "Fix runtime")
: > "$STUB_DIR/block-pr"
export GITHUB_OUTPUT="$work/output"
run notproton.sh
has "policy block opens an actionable issue" "manual PR needed" "$STUB_LOG"
has "issue links the prepared comparison" "compare/main...sync/notproton-$sha?expand=1" "$STUB_LOG"
has "CI still receives the prepared branch" "branch=sync/notproton-$sha" "$GITHUB_OUTPUT"
hasnt "fallback exits successfully" "exit [1-9]" "$work/out"
run notproton.sh
hasnt "policy block is not reported twice" "issue create" "$STUB_LOG"
rm -f "$STUB_DIR/block-pr"
unset GITHUB_OUTPUT

echo "== NotProton: a conflict becomes an issue =="
checkout
origin_commit steam.cpp 'line one\nours\n' "our change"
sha=$(upstream_commit steam.cpp 'line one\ntheirs\n' "their change")
run notproton.sh
has "an issue is created" "issue create .* --title NotProton $sha does not merge cleanly" "$STUB_LOG"
hasnt "no PR is created" "pr create" "$STUB_LOG"
is "no branch is pushed" "0" "$(git -C "$work/origin.git" branch --list "sync/notproton-*" | wc -l | tr -d ' ')"
is "the checkout is left clean" "" "$(git -C "$work/repo" status --porcelain)"
printf '7\n' > "$STUB_DIR/issues"
run notproton.sh
hasnt "with the issue open, no second issue" "issue create" "$STUB_LOG"
rm -f "$STUB_DIR/issues"

echo "== Highball: pin and database =="
hb() {   # pinned-kit db-commit
  rm -rf "$work/hb" "$work/hb-origin.git"
  mkdir -p "$work/hb/app/Sources/HighballEnvCore" "$work/hb/third_party/highball-db" "$work/hb/scripts/sync"
  cp "$here"/common.sh "$here"/highball.sh "$work/hb/scripts/sync/"
  printf '        .package(url: "https://github.com/gauthierpiarrette/highball", exact: "%s"),\n' "$1" > "$work/hb/app/Package.swift"
  printf 'public static let highballKitVersion = "%s"\n' "$1" > "$work/hb/app/Sources/HighballEnvCore/HighballEnvCore.swift"
  printf '{"source":{"commit":"%s"},"games":[],"recipes":[]}\n' "$2" > "$work/hb/third_party/highball-db/highball-db.json"
  printf '{"pins":[{"identity":"highball","location":"https://github.com/gauthierpiarrette/highball","kind":"remoteSourceControl","state":{"revision":"0000000000000000000000000000000000000000","version":"%s"}}],"version":3}\n' "$1" > "$work/hb/app/Package.resolved"
  git_quiet -C "$work/hb" init -q && git_quiet -C "$work/hb" add -A && git_quiet -C "$work/hb" commit -q -m base
  git_quiet clone -q --bare "$work/hb" "$work/hb-origin.git"
  git_quiet -C "$work/hb" remote add origin "$work/hb-origin.git"
  git_quiet -C "$work/hb" fetch -q origin
}
# A write-capable sync must never execute a Swift manifest; the stub records violations.
cat > "$work/bin/swift" <<'STUB'
#!/bin/sh
touch "$STUB_DIR/unsafe-resolve"; exit 99
STUB
cat > "$work/bin/refresh-db" <<'STUB'
#!/bin/sh
printf '{"source":{"commit":"%s"},"games":[],"recipes":[]}\n' "$1" > third_party/highball-db/highball-db.json
STUB
chmod +x "$work/bin/swift" "$work/bin/refresh-db"
export SWIFT="$work/bin/swift" REFRESH_DB="$work/bin/refresh-db"
runhb() { : > "$STUB_LOG"; sh "$work/hb/scripts/sync/highball.sh" > "$work/out" 2>&1 || echo "exit $?" >> "$work/out"; }

hb 0.10.15 aaaaaaa1111
printf 'v0.10.15\n' > "$STUB_DIR/releases"; printf 'aaaaaaa1111\n' > "$STUB_DIR/dbhead"
runhb
has "nothing newer reports current" "are current" "$work/out"
hasnt "and opens nothing" "create" "$STUB_LOG"

printf 'v0.10.16\n' > "$STUB_DIR/releases"
runhb
has "a newer Highball release opens a PR" "pr create .* --head sync/highball-0.10.16 " "$STUB_LOG"
is "the pin is bumped" "1" "$(git -C "$work/hb-origin.git" show sync/highball-0.10.16:app/Package.swift | grep -c 'exact: "0.10.16"')"
is "the dependency commit is pinned without executing a manifest" "0000000000000000000000000000000000000001" "$(git -C "$work/hb-origin.git" show sync/highball-0.10.16:app/Package.resolved | python3 -c 'import json,sys;print(json.load(sys.stdin)["pins"][0]["state"]["revision"])')"
is "no package code executes with write credentials" "no" "$([ -f "$STUB_DIR/unsafe-resolve" ] && echo yes || echo no)"
is "the helper's version constant follows" "1" "$(git -C "$work/hb-origin.git" show sync/highball-0.10.16:app/Sources/HighballEnvCore/HighballEnvCore.swift | grep -c '"0.10.16"')"
runhb
hasnt "a second run opens no second PR" "pr create" "$STUB_LOG"

hb 0.10.15 aaaaaaa1111
printf 'v0.10.9\n' > "$STUB_DIR/releases"
runhb
hasnt "an older release is not a downgrade" "pr create" "$STUB_LOG"

hb 0.10.15 aaaaaaa1111
: > "$STUB_DIR/annotated"
printf 'v0.10.16\n' > "$STUB_DIR/releases"; printf 'bbbbbbb2222\n' > "$STUB_DIR/dbhead"
runhb
has "both newer go in one PR" "--head sync/highball-0.10.16-db-bbbbbbb " "$STUB_LOG"
is "the snapshot is refreshed" "1" "$(git -C "$work/hb-origin.git" show sync/highball-0.10.16-db-bbbbbbb:third_party/highball-db/highball-db.json | grep -c bbbbbbb2222)"

has "annotated tags are resolved to their commit" "api repos/gauthierpiarrette/highball/git/tags/" "$STUB_LOG"
rm -f "$STUB_DIR/annotated"

hb 0.10.15 aaaaaaa1111
printf 'v0.10.16-invalid\n' > "$STUB_DIR/releases"
runhb
has "unexpected tags are refused" "refusing an unexpected" "$work/out"
hasnt "a refused tag opens no PR" "pr create" "$STUB_LOG"

echo "== Highball: blocked PR remains reviewable =="
hb 0.10.15 aaaaaaa1111
printf 'v0.10.16\n' > "$STUB_DIR/releases"; printf 'aaaaaaa1111\n' > "$STUB_DIR/dbhead"
: > "$STUB_DIR/block-pr"
runhb
has "Highball policy block opens a review issue" "manual PR needed" "$STUB_LOG"
has "Highball issue includes comparison link" "compare/main...sync/highball-0.10.16?expand=1" "$STUB_LOG"
hasnt "Highball fallback exits successfully" "exit [1-9]" "$work/out"
rm -f "$STUB_DIR/block-pr"

echo "== Highball engines =="
eng() {
  rm -rf "$work/eng"; mkdir -p "$work/eng/scripts/sync"
  cp "$here"/common.sh "$here"/highball-engine.sh "$work/eng/scripts/sync/"
  printf 'engine-wine-11.0-20261005T184024Z-0019-forza-trial\n' > "$work/eng/scripts/sync/known-highball-engine"
}
runeng() { : > "$STUB_LOG"; sh "$work/eng/scripts/sync/highball-engine.sh" > "$work/out" 2>&1 || echo "exit $?" >> "$work/out"; }
eng
printf 'engine-wine-11.0-20261014T003801Z-0024-app-packages\nd3dmetal-tsshim-20261014\nengine-wine-11.0-20261005T184024Z-0019-forza-trial\nengine-wine-11.0-20261001T000000Z-0015-old\n' > "$STUB_DIR/releases"
runeng
is "only the newer engine gets an issue" "1" "$(grep -c "issue create" "$STUB_LOG")"
has "named after its tag" "New Highball engine engine-wine-11.0-20261014T003801Z-0024-app-packages" "$STUB_LOG"
printf '3\n' > "$STUB_DIR/issues"
runeng
hasnt "with its issue open, nothing new" "issue create" "$STUB_LOG"
rm -f "$STUB_DIR/issues"

if [ "$fails" -ne 0 ]; then echo "==> sync: $fails check(s) failed"; exit 1; fi
echo "==> sync: NotProton merges and conflicts, Highball bumps and engines all answer"
