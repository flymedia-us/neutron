#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo=flymedia-us/neutron
test "$GITHUB_REPOSITORY" = "$repo"
(cd release && sha256sum -c SHA256SUMS)
# 'updates' is a permanent prerelease containing only the rolling feed. It never
# replaces GitHub's latest stable release or supplies executable content itself.
previous=()
if gh release view updates --repo "$repo" --json assets > release/feed-assets.json 2>/dev/null; then
  if jq -e '.assets[] | select(.name == "appcast.xml")' release/feed-assets.json >/dev/null; then
    mkdir -p release/previous
    gh release download updates --repo "$repo" --pattern appcast.xml --dir release/previous
    previous=(--previous release/previous/appcast.xml)
  fi
else
  gh release create updates --repo "$repo" --target "$GITHUB_SHA" --title 'Neutron update feed' \
    --notes 'Signed update metadata for Neutron. Download the app from a versioned release.' --prerelease --latest=false
fi
# Reject a late release of an older commit before changing any public version.
python3 - release/item.xml "${previous[@]:1}" <<'PYCODE'
import pathlib, sys, xml.etree.ElementTree as ET
ns = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
build = int(ET.parse(sys.argv[1]).getroot().findtext(ns + 'version'))
if len(sys.argv) > 2:
    existing = [int(i.findtext(ns + 'version')) for i in ET.parse(sys.argv[2]).findall('./channel/item')]
    if existing and build < max(existing):
        sys.exit('A newer commit has already been released; refusing to publish an older build.')
PYCODE
python3 scripts/release-metadata.py feed release/item.xml release/appcast.xml "${previous[@]}"
# A retry can finish a draft or repair a feed after publishing. Never overwrite
# public binaries: a rerun only accepts exactly the already published checksum.
published=false
if gh release view "$RELEASE_TAG" --repo "$repo" --json isDraft > release/existing.json 2>/dev/null; then
  if jq -e '.isDraft == false' release/existing.json >/dev/null; then
    mkdir -p release/published
    gh release download "$RELEASE_TAG" --repo "$repo" --pattern SHA256SUMS --dir release/published
    cmp release/SHA256SUMS release/published/SHA256SUMS || { echo 'Published release differs; create a new version.' >&2; exit 1; }
    published=true
  fi
else
  args=(--draft --verify-tag --title "Neutron $RELEASE_VERSION" --generate-notes)
  if [ "$PRERELEASE" = true ]; then args+=(--prerelease --latest=false); fi
  gh release create "$RELEASE_TAG" --repo "$repo" "${args[@]}"
fi
if [ "$published" = false ]; then
  gh release upload "$RELEASE_TAG" release/Neutron.zip release/SHA256SUMS release/SOURCE.json --repo "$repo" --clobber
fi
# Publish the downloadable release before advertising it to installed apps.
args=(--draft=false)
if [ "$PRERELEASE" = true ]; then args+=(--prerelease --latest=false); else args+=(--prerelease=false --latest); fi
gh release edit "$RELEASE_TAG" --repo "$repo" "${args[@]}"
gh release upload updates release/appcast.xml --repo "$repo" --clobber
