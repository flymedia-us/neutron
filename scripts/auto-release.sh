#!/bin/bash
# Version changes on reviewed main create a tag and explicitly start the release.
# GITHUB_TOKEN-created tags alone do not trigger other push workflows.
set -euo pipefail
cd "$(dirname "$0")/.."
test "$GITHUB_REPOSITORY" = flymedia-us/neutron
test "$GITHUB_REF" = refs/heads/main
plan=$(python3 scripts/release-metadata.py pending-tag)
if [ "$(printf '%s' "$plan" | python3 -c 'import json,sys; print(json.load(sys.stdin)["pending"])')" != True ]; then
  echo 'This version has already been tagged; no new release is needed.'
  exit 0
fi
tag=$(printf '%s' "$plan" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag"])')
sha=$(git rev-parse HEAD)
test "$sha" = "$GITHUB_SHA"
# A rerun after tag creation can recover an interrupted dispatch. Never duplicate
# an existing run or overwrite a tag; recover a failed release from its own run.
existing=$(gh run list --repo "$GITHUB_REPOSITORY" --workflow release.yml --branch "$tag" --limit 1 --json databaseId)
if [ "$existing" != '[]' ]; then echo "A release run already exists for $tag."; exit 0; fi
if ! git rev-parse --verify "refs/tags/$tag^{commit}" >/dev/null 2>&1; then
  gh api --method POST "repos/$GITHUB_REPOSITORY/git/refs" \
    -f "ref=refs/tags/$tag" -f "sha=$sha" --silent
fi
gh workflow run release.yml --repo "$GITHUB_REPOSITORY" --ref "$tag"
echo "Started automatic release $tag."
