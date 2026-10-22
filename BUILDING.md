# Building Neutron

Use the toolchain and dependency pins in `README.md` and `.github/workflows/app.yml`.
Install Rosetta 2 before building the x86_64 bridge on an Apple Silicon Mac.
Build on a branch and submit a PR; `main` requires successful app and shell checks.

## Fly Media signing on a Mac

Fly Media LLC's Apple Developer team is `BJZSH247Q9`. Team identifiers and public
certificate fingerprints are not credentials. Private keys remain in Keychain.

```sh
make app-flymedia
```

This target requires a valid Apple signing identity belonging to that team. It
prefers a Developer ID Application certificate when one is installed, otherwise
uses an Apple Development certificate for that team. It signs nested Mach-O code
before the containing app, enables hardened runtime for certificate signatures,
and verifies every signed file's TeamIdentifier. A missing or wrong company
identity fails the company build rather than silently producing an ad hoc build.

The regular `make app` also selects the company's identity when available, but
falls back to ad hoc signing on contributors' Macs. CI explicitly selects
`APP_SIGN_ID=-`; CI artifacts do not contain or use Fly Media's private keys.

The local Mac verified on 2026-10-21 has the **Developer ID Application: Fly Media LLC
(BJZSH247Q9)** identity, SHA-1 `120D2200993750D65F7CC0BC117EDE47DEA94AEC`.
The signer prefers this identity when available. Verify it with
`security find-identity -v -p codesigning` before a distribution build.
A Developer ID signature alone is not notarization. Public Gatekeeper-friendly
releases also need Apple's notarization process. See [RELEASING.md](RELEASING.md).

No new Apple certificates are created by these build scripts. Signing or
notarization credentials must never be committed or uploaded in build logs.
The local signing identity Neutron creates for *modified Steam* is separate from
the Fly Media identity used to sign *Neutron.app*; company private keys are never
distributed to users or needed for their Steam integration.

## Licenses and source

Each app includes `Contents/Resources/Licenses`, with unchanged license texts,
copyright-bearing dependency sources, and `SOURCE.json` pointing at the exact
source revision. Original font licenses remain with the fonts. See `NOTICE` and
`THIRD_PARTY_NOTICES.md` for the component terms and original contributors.
Use the published source commit for a shared binary; uncommitted source changes
must be committed and pushed before distributing a release.

## Necessary upstream spelling

User-facing Neutron setup and Steam UI use Wine/Highball terminology. Upstream
names remain only where replacing them would obscure provenance, invalidate a
license check, or break compatibility:

- Highball's exact engine ID and manifest names, such as `x64-crossover26.3-r19`,
  are used for download selection, hashes, detour tables and installed tool IDs.
- Existing Wine user profiles, runtime markers, old launcher signatures and
  external bundle paths are read using their original names to protect existing
  prefixes and saves.
- The inherited legacy runtime adapter retains accurate type names, hash tables,
  and activation verification. It has no Neutron setup UI. Do not turn it into an
  activation bypass by deleting its checks or pretending it is the free engine.
- Fixtures exercise those external and historical formats. Upstream Git history,
  source attribution and license texts are preserved without cosmetic rewriting.

`make brandcheck` checks the app interface, prefix dialogs, Steam panel and issue
template. `make app-tests`, native suites and filesystem checks cover the retained
compatibility contracts. Run the relevant checks before requesting review.
