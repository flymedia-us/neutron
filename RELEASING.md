# GitHub releases and automatic updates

Neutron is distributed directly through `flymedia-us/neutron` on GitHub. No App
Store submission, provisioning profile, App Sandbox, paid runtime, or third-party
hosting is required. Fly Media's Apple Developer team is `BJZSH247Q9`.

A push of a `v*` tag starts `.github/workflows/release.yml`. The tag must exactly
match `dylib/version.h`, point to a commit in reviewed `main`, and use `X.Y.Z` or
`X.Y.Z-alpha.N`, `-beta.N`, or `-rc.N`. Upstream sync never creates release tags.

The workflow validates the source, runs the full app CI build and tests, and then
imports signing credentials into a temporary Keychain on a GitHub-hosted Mac.
It verifies every Mach-O file belongs to Fly Media and carries Developer ID
Application signing with hardened runtime. Nested Sparkle helper apps, XPC
services and framework bundles are signed inside out. Apple must accept
notarization; the ticket is stapled and verified, and Gatekeeper assessment must
pass before any app is published. There is no unsigned fallback for releases.

## One-time Fly Media configuration

AppleTree already has the five shared Apple signing/notarization secrets and
has published successful signed, notarized releases. Neutron uses the same names
and formats. Reuse the original Fly Media `.p12` export and `.p8` key if available;
a separate certificate per app is unnecessary. GitHub does not reveal stored
secret values, so they cannot be copied back out of AppleTree's settings. If
those source files are unavailable, recover the identity from the Mac that has
its private key or create replacement credentials. Do not revoke AppleTree's
working credentials as part of setting up Neutron.

The local Mac inspected on 2026-10-19 had only an Apple Development identity;
this does not mean Fly Media lacks a Developer ID certificate elsewhere.

1. In Fly Media's Apple Developer account, create or obtain a **Developer ID
   Application** certificate, with its private key available in Keychain. Use
   the team `BJZSH247Q9`. Export that identity as a password-protected `.p12`.
   If a certificate already exists on another company Mac, use its exported
   identity rather than creating unrelated company certificates.
2. Obtain an App Store Connect team API key authorized to use Apple's notary
   service. Despite the account name, this is for direct macOS distribution;
   it does not publish Neutron to the App Store. Keep its `.p8`, key ID and
   issuer ID private.
3. Download the reviewed Sparkle **2.10.0** distribution from its official GitHub
   release. Its `Sparkle-2.10.0.tar.xz` SHA-256 is
   `c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c`.
   Run `bin/generate_keys --account us.flymedia.neutron` once to create Neutron's
   own Ed25519 update key in Keychain. Save the displayed **public** key as the
   `release` environment Actions variable `SPARKLE_PUBLIC_KEY`. Export the corresponding
   private key with `bin/generate_keys --account us.flymedia.neutron -x /private/tmp/neutron-sparkle.key`
   and upload its file contents as the secret `SPARKLE_PRIVATE_KEY`.
   Back up the key securely; never reuse an upstream publisher's key.
4. The GitHub environment **release** has been created and restricted to `v*`
   tags. Add these environment secrets
   (repository secrets also work). Use `gh secret set NAME --env release
   --repo flymedia-us/neutron` with input from the file or standard input so
   secrets never appear in command arguments or shell history.

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Base64 encoding of the Fly Media `.p12` identity |
| `DEVELOPER_ID_P12_PASSWORD` | Its export password |
| `APP_STORE_CONNECT_API_KEY` | Raw `.p8` text, including the BEGIN/END lines (same format as AppleTree) |
| `APP_STORE_CONNECT_KEY_ID` | API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | API issuer ID |
| `SPARKLE_PRIVATE_KEY` | The text exported by Sparkle `generate_keys -x` |

The `SPARKLE_PUBLIC_KEY` Actions **variable** in the `release` environment contains the public key, never the
private key. The release job embeds it in the app's `SUPublicEDKey`. Keep it
stable between releases. The workflow verifies the ZIP signature against this
public key, so mismatched keys fail before publishing.

Keep credentials outside this repository. The workflow deletes its temporary
Keychain and private files on exit and uploads only the app, checksums, public
metadata and source reference. Forks and pull requests run ad hoc CI without
release credentials. Protect `main` and restrict release tag creation to
maintainers; restrict the release environment to reviewed `v*` tags. Optional
required reviewers may be added according to Fly Media's release policy.

## Shared Fly Media release convention

Both projects use version tags from reviewed `main`, CI before signing, Fly
Media Developer ID (`BJZSH247Q9`), hardened runtime, Apple notarization, stapling,
and verification before publishing on GitHub. Packaging differs deliberately:

| Project/channel | Artifact | Updates |
| --- | --- | --- |
| Neutron on GitHub | Notarized app ZIP | Sparkle checks GitHub and installs authenticated updates; automatic installation is optional |
| AppleTree on GitHub | Signed, notarized DMG | Manual downloads; no updater or update feed |
| AppleTree on the Mac App Store | App Store distribution | Managed by the App Store; the preferred purchase supports development |

The five `DEVELOPER_ID_*` and `APP_STORE_CONNECT_*` secret names above match
[AppleTree's release setup](https://github.com/flymedia-us/appletree/blob/main/docs/releasing.md).
`APP_STORE_CONNECT_API_KEY` is the raw `.p8` text, not base64. The account name
does not imply an App Store submission: `notarytool` uses that API key for direct
macOS distribution too. Neutron alone needs `SPARKLE_PRIVATE_KEY` and
`SPARKLE_PUBLIC_KEY`. Do not copy AppleTree's `APP_STORE_DISTRIBUTION_*` or
provisioning-profile secrets into Neutron; those serve AppleTree's separate
App Store pipeline.

## Upload the credentials without exposing them

In [Neutron Settings → Environments → release](https://github.com/flymedia-us/neutron/settings/environments),
add the six secrets from the table and the public `SPARKLE_PUBLIC_KEY` variable.
Or use GitHub CLI. Substitute the paths to your existing private files; the
commands read secret contents from standard input or a hidden prompt:

```sh
base64 -i /path/to/FlyMedia-DeveloperID.p12 | gh secret set DEVELOPER_ID_P12_BASE64 --env release --repo flymedia-us/neutron
gh secret set DEVELOPER_ID_P12_PASSWORD --env release --repo flymedia-us/neutron
gh secret set APP_STORE_CONNECT_API_KEY --env release --repo flymedia-us/neutron < /path/to/AuthKey_KEYID.p8
gh secret set APP_STORE_CONNECT_KEY_ID --env release --repo flymedia-us/neutron
gh secret set APP_STORE_CONNECT_ISSUER_ID --env release --repo flymedia-us/neutron
```

The password must be the `.p12` export password, and the API IDs must belong to
the `.p8` file being uploaded. Store Neutron's Sparkle keys after generating them
with the pinned Sparkle distribution as described above:

```sh
gh secret set SPARKLE_PRIVATE_KEY --env release --repo flymedia-us/neutron < /path/to/neutron-sparkle.key
gh variable set SPARKLE_PUBLIC_KEY --env release --repo flymedia-us/neutron
```

Enter the public key printed by `generate_keys` at the last prompt. The exported
private key file is already base64 text: do not base64-encode it a second time.
Keep a secure backup of the original Apple credentials and the Sparkle key. You
can list configured names with `gh secret list --env release --repo flymedia-us/neutron`;
listing names does not reveal or validate their values.

## Why notarization is part of every release

For the intended first-install experience under normal Gatekeeper settings,
Neutron needs Developer ID signing **and** Apple notarization. Signing identifies
Fly Media and protects integrity; notarization is Apple's automated malware and
signing check. It does not put Neutron in the App Store or submit it for review.

There is no per-release manual notarization task after the credentials are set:
the release job signs the app, ZIPs it, submits it with `notarytool`, waits for
Apple to accept it, staples the ticket to the app, verifies it with Gatekeeper,
then creates the final ZIP and signs that archive for Sparkle. Stapling makes
the ticket travel with the download, including for offline verification. The
job stops if any check fails. AppleTree's DMG pipeline follows the same process
and also notarizes the disk image. App Store builds use the store's equivalent
checks rather than this separate direct-distribution flow.

If replacement credentials are needed, obtain a **Developer ID Application**
certificate in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list).
Use the Fly Media team, create a certificate signing request in Keychain Access,
upload the request, download and install the `.cer`, then export the resulting
certificate **with its private key** as `.p12` from My Certificates. A `.cer`
alone does not contain the private key required by CI. Apple requires the Account
Holder role for creating this Developer ID certificate.

For a replacement team API key, use [App Store Connect → Users and Access →
Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api).
Create a team key with a role authorized for notarization (Developer is sufficient
for this purpose; an existing authorized AppleTree key also works). Download the
`.p8` when offered and record its Key ID and the team's Issuer ID. The private
key is downloadable only once. Neutron does not require AppleTree's App Store
provisioning profile, Mac App Distribution certificate, or installer certificate.

## Publish a version

1. Change `dylib/version.h` in a PR, for example to `0.1.0-alpha.5`. Keep Neutron's
   version separate from NotProton's upstream version. Merge after CI passes.
2. Tag the merged commit and push the tag:

   ```sh
   git fetch origin main
   git tag -a v0.1.0-alpha.5 origin/main -m 'Neutron 0.1.0-alpha.5'
   git push origin v0.1.0-alpha.5
   ```

3. Watch the **release** workflow. It publishes `Neutron.zip`, `SHA256SUMS`, and
   `SOURCE.json` on the versioned release. GitHub also provides source archives;
   the app bundles original component notices, dependency revisions, and the
   precise source URL. Preserve the source tag and build instructions for every
   distributed binary. No credentials or downloaded proprietary engines are
   added to the source repository or release assets.

The automatic update feed is the `appcast.xml` asset on the permanent **updates**
prerelease. All hosting remains on GitHub. This metadata release is never marked
as the latest stable release. Updates are advertised only after the versioned
app release becomes downloadable. Stable clients ignore items in the `preview`
channel; prerelease clients accept previews and stable releases. Feed history
retains the last stable version when previews are published.

`CFBundleVersion` uses the tagged commit's total revision count. Tags must be
released in increasing commit order. A retry can finish a draft or repair a feed
using the exact previously uploaded signed artifact; public version assets are
never overwritten. If publication fails after signing, rerun the failed publish
job so it reuses the signed artifact. For changed binaries, create a new version.
Use manual workflow dispatch **on the existing tag** to recover a failed run.

## Verify an actual public release

Test a downloaded, quarantined ZIP on a clean Mac: move the app to Applications,
open it, and confirm Gatekeeper accepts the notarized Fly Media signature. A
normal first-launch confirmation may remain. Signing and notarization remove
the unidentified-developer **Open Anyway** workaround; macOS still controls
App Management, Accessibility, and removable-volume permission prompts.

Test a real older signed release updating to a newer signed release through
**Check for Updates…**, including relaunch. Local tests verify packaging,
channels and signatures, but cannot replace Apple's notarization service or an
end-to-end update between two published releases. Automatic update checking is
on for official builds; unattended installation remains a user choice.

Contributor builds use `make app APP_SIGN_ID=-`. Without `SPARKLE_PUBLIC_KEY`,
background updates and the update command are disabled. Contributors do not
need company certificates or private keys. `make app-flymedia` can use a local
company development identity; it does not claim to produce a notarized public
release.

References: [Apple Developer ID](https://developer.apple.com/developer-id/),
[Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution),
[Sparkle publishing](https://sparkle-project.org/documentation/publishing/).
