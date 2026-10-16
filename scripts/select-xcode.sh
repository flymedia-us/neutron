#!/bin/sh
set -eu
# Use a supported SDK on both GitHub-hosted runners and a developer's Mac.
for xcode in /Applications/Xcode_27*.app /Applications/Xcode.app; do
  [ -d "$xcode" ] || continue
  developer="$xcode/Contents/Developer"
  version=$(DEVELOPER_DIR="$developer" xcodebuild -version | head -1)
  case "$version" in 'Xcode 27'*)
    if [ -n "${GITHUB_ENV:-}" ]; then printf 'DEVELOPER_DIR=%s\n' "$developer" >> "$GITHUB_ENV"; fi
    printf '%s\n' "$version"
    exit 0 ;;
  esac
done
echo 'Neutron requires Xcode 27 or newer; install it or select an appropriate runner.' >&2
exit 1
