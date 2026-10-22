#!/bin/bash
# Adapted from Fly Media AppleTree's DMG packaging (GPLv3).
# Packages an already signed app without changing anything inside its resource seal.
set -euo pipefail
# The release caller uses 077 for private credentials. This subprocess only
# handles public installer files, which must be readable on other Macs.
umask 022
if [ "$#" -ne 2 ]; then echo "usage: $0 <Neutron.app> <output.dmg>" >&2; exit 2; fi
root=$(cd "$(dirname "$0")/.." && pwd)
app=$1
output=$2
test -d "$app" || { echo "Missing app bundle: $app" >&2; exit 1; }
test -f "$app/Contents/Resources/Neutron.icns"
test -f "$app/Contents/Resources/Licenses/SOURCE.json"
codesign --verify --deep --strict "$app"
work=$(mktemp -d)
mounted=0
cleanup() {
  if [ "$mounted" = 1 ]; then hdiutil detach -force "$work/mount" >/dev/null 2>&1 || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
ditto "$app" "$work/Neutron.app"
swift "$root/packaging/dmg/render-background.swift" "$work"
python3 -m venv "$work/venv"
"$work/venv/bin/pip" install --quiet --disable-pip-version-check -r "$root/packaging/dmg/requirements.txt"
mkdir -p "$(dirname "$output")"
"$work/venv/bin/dmgbuild" -s "$root/packaging/dmg/settings.py" \
  -D "app=$work/Neutron.app" -D "icon=$app/Contents/Resources/Neutron.icns" \
  -D "background=$work/background@2x.png" Neutron "$output"
mkdir "$work/mount"
hdiutil attach -readonly -nobrowse -mountpoint "$work/mount" "$output" > /dev/null
mounted=1
test "$(readlink "$work/mount/Applications")" = /Applications
codesign --verify --deep --strict "$work/mount/Neutron.app"
hdiutil detach "$work/mount"
mounted=0
echo "Built $output"
