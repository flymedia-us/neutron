#!/bin/sh
# shellcheck disable=SC2016
# Shared by the upstream sync scripts. Sourced, not run.
# GH names the gh binary (tests stub it); REPO is this fork for gh calls.

GH="${GH:-gh}"
REPO="${REPO:-flymedia-us/neutron}"

sync_log() { printf 'sync: %s\n' "$*"; }

# 0 when a branch of that name exists on origin
branch_exists() { git ls-remote --exit-code --heads origin "$1" >/dev/null 2>&1; }

# 0 when an open upstream-sync issue mentions the text
issue_exists() {
  [ -n "$("$GH" issue list -R "$REPO" --label upstream-sync --state open --search "$1" --json number -q '.[0].number' 2>/dev/null)" ]
}

# 0 when an open PR comes from the branch
pr_exists() {
  [ -n "$("$GH" pr list -R "$REPO" --head "$1" --state open --json number -q '.[0].number' 2>/dev/null)" ]
}

# Bot commits carry the no-reply identity, never a work address
git_identity() {
  git config user.name "Neutron sync"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
}

footer() {
  printf '\n---\nOpened by the upstream-sync workflow. It never bumps `dylib/version.h`, so merging this does not publish a release.\n'
}

# Organization policy can forbid bot-created PRs. Keep the prepared branch reviewable
# without changing policy or granting credentials broader access.
open_review() (
  branch=$1
  label=$2
  title=$3
  body=$4
  review_tmp=$(mktemp -d)
  trap 'rm -rf "$review_tmp"' EXIT
  printf '%s\n' "$body" > "$review_tmp/body.md"
  if "$GH" pr create -R "$REPO" --base main --head "$branch" \
      --title "$title" --label upstream-sync --label "$label" --body-file "$review_tmp/body.md"; then
    sync_log "opened a PR for $branch"
  else
    printf 'The update branch is ready, but GitHub refused automatic PR creation. Repository or organization policy may block it. No permission changes were made.\n\nReview and open a PR: https://github.com/%s/compare/main...%s?expand=1\n\n%s\n' \
      "$REPO" "$branch" "$body" > "$review_tmp/issue.md"
    "$GH" issue create -R "$REPO" --title "$title: manual PR needed" \
      --label upstream-sync --label "$label" --body-file "$review_tmp/issue.md"
    sync_log "PR creation unavailable; opened a review issue for $branch"
  fi
)
