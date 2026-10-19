#!/bin/bash
# Used only by the release environment, after the source and full build pass.
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
for name in DEVELOPER_ID_P12_BASE64 DEVELOPER_ID_P12_PASSWORD APP_STORE_CONNECT_API_KEY \
  APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID SPARKLE_PRIVATE_KEY SPARKLE_PUBLIC_KEY RELEASE_VERSION RELEASE_BUILD; do
  if [ -z "${!name:-}" ]; then echo "Missing release configuration: $name" >&2; exit 1; fi
done
work=$(mktemp -d)
keychain="$work/release.keychain-db"
cleanup() {
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT
# Keep private material outside the checkout and all uploaded artifact paths.
printf '%s' "$DEVELOPER_ID_P12_BASE64" | base64 --decode > "$work/signing.p12"
printf '%s\n' "$APP_STORE_CONNECT_API_KEY" > "$work/AuthKey.p8"
printf '%s' "$SPARKLE_PRIVATE_KEY" > "$work/sparkle.key"
password=$(openssl rand -hex 32)
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 3600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$work/signing.p12" -k "$keychain" -P "$DEVELOPER_ID_P12_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
# This is an ephemeral GitHub-hosted runner, never a developer's login keychain.
security list-keychains -d user -s "$keychain"
ditto -x -k release/Neutron.zip "$work/unpacked"
app="$work/unpacked/Neutron.app"
python3 - "$app/Contents/Resources/Licenses/SOURCE.json" <<'PYCODE'
import json, os, sys
source = json.load(open(sys.argv[1]))
if source.get('uncommitted_changes') or source.get('revision') != os.environ['GITHUB_SHA']:
    sys.exit('The build provenance does not match this clean release commit.')
PYCODE
actual=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
test "$actual" = "$RELEASE_VERSION"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $RELEASE_BUILD" "$app/Contents/Info.plist"
python3 scripts/configure-updater.py "$app/Contents/Info.plist"
python3 scripts/sign-app.py "$app" --identity auto --team BJZSH247Q9 --require-team 1 --distribution
ditto -c -k --sequesterRsrc --keepParent "$app" "$work/notarize.zip"
xcrun notarytool submit "$work/notarize.zip" --key "$work/AuthKey.p8" \
  --key-id "$APP_STORE_CONNECT_KEY_ID" --issuer "$APP_STORE_CONNECT_ISSUER_ID" --wait --timeout 30m --output-format json > "$work/notary.json"
python3 - "$work/notary.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    sys.exit('Apple did not accept notarization; no release will be published. Submission: ' + result.get('id', 'unknown'))
print('Apple notarization accepted.')
PY
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --deep --strict "$app"
spctl --assess --type execute --verbose=2 "$app"
rm release/Neutron.zip
ditto -c -k --sequesterRsrc --keepParent "$app" release/Neutron.zip
cp "$app/Contents/Resources/Licenses/SOURCE.json" release/SOURCE.json
# Download the exact Sparkle distribution pinned in Package.resolved. The app
# framework itself was already checked against SwiftPM's archive checksum.
sparkle_version=$(python3 -c 'import json; print(next(p["state"]["version"] for p in json.load(open("app/Package.resolved"))["pins"] if p["identity"] == "sparkle"))')
curl --fail --location --retry 3 --connect-timeout 30 --max-time 300 --proto '=https' --tlsv1.2 \
  "https://github.com/sparkle-project/Sparkle/releases/download/$sparkle_version/Sparkle-$sparkle_version.tar.xz" -o "$work/sparkle.tar.xz"
# Revalidate this checksum whenever the reviewed Sparkle pin changes.
test "$sparkle_version" = 2.10.0
printf '%s  %s\n' c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c "$work/sparkle.tar.xz" | shasum -a 256 -c -
tar -xJf "$work/sparkle.tar.xz" -C "$work"
python3 - "$work/sparkle.key" <<'PYCODE'
import base64, pathlib, sys
try:
    key = base64.b64decode(pathlib.Path(sys.argv[1]).read_text().strip(), validate=True)
    if len(key) not in (32, 96):
        raise ValueError()
except ValueError:
    sys.exit('SPARKLE_PRIVATE_KEY has an invalid format; export it with Sparkle generate_keys.')
PYCODE
signature=$("$work/bin/sign_update" --ed-key-file "$work/sparkle.key" -p release/Neutron.zip)
# Verify against the public key embedded in the app, not just against the secret
# used to sign it. A misconfigured pair must fail before publishing.
swift scripts/verify-update.swift release/Neutron.zip "$signature" "$SPARKLE_PUBLIC_KEY"
python3 scripts/release-metadata.py item "$app" release/Neutron.zip "$signature" release/item.xml
(cd release && shasum -a 256 Neutron.zip SOURCE.json > SHA256SUMS)
