# Neutron

Free Steam Play for Apple Silicon Macs, by Fly Media. Neutron lets the normal macOS Steam client launch Windows games through Highball's free Wine engine. It includes guided engine setup and fixes for games stored on external exFAT drives.

Neutron is a fork of NotProton by [NotProtonNot](https://github.com/NotProtonNot/NotProton). Its Highball integration is adapted from [Proton-ish](https://github.com/MagnusPladsen/Proton-ish), with attribution preserved. It uses [HighballKit and Highball's engine](https://github.com/gauthierpiarrette/highball) and the [highball-db](https://github.com/gauthierpiarrette/highball-db) compatibility data. Neutron is not affiliated with or endorsed by these projects, Valve, or Apple.

## Set up

You need an Apple Silicon Mac, macOS 15 or later, Steam for macOS, and Rosetta 2.

1. Download `Neutron.zip` from this repository's Releases and move `Neutron.app` to Applications. Until a release is published, build from source below or use a successful Actions build artifact.
2. Open Neutron. CI builds are ad hoc signed; macOS may require **Privacy & Security → Open Anyway**. Allow App Management when requested, because Neutron patches Steam.
3. Click **Set Up Neutron**. Read Apple's D3DMetal license and choose whether to accept it. Neutron installs the Steam integration, downloads or reuses Highball's engine, verifies its downloads, sets up the compatibility tool, and makes it the default when Steam has none. No separate Highball app is needed.
4. Start Steam normally from its Mac app. Windows-only games show Play. For a game with a native Mac version, select Neutron's Highball tool under **Properties → Compatibility** to use the Windows version.

The download is about 440 MB plus any missing Steam components. D3DMetal is optional and is used only after Apple's license is accepted. Without it, DXMT/DXVK are available, but games requiring D3DMetal will not work. **Check for Updates** opens Neutron's own releases page; updates are installed explicitly.

## External and portable libraries

Keep your Windows Steam library on the existing exFAT drive and add that same library in Steam on each computer. Neutron handles macOS AppleDouble metadata and copies prefix files when the drive rejects hard links. Highball's template creation receives the engine's library paths. These fixes are embedded in Neutron; no launcher patch needs to be reapplied after restarting Steam.

The game payload and Mac Wine prefixes can stay on the drive. Steam, Neutron, the engine, permissions, and prerequisites still need setup on each host. A drive cannot make every Windows game compatible with every Mac. DRM, other launchers, anti-cheat, and game-specific save locations can limit portability. This exFAT behavior was tested on macOS 27; other filesystem drivers can differ. Do not reformat an existing drive to try Neutron.

**Tetris Effect: Connected (1003590):** Automatic uses D3DMetal when available; this reached a visible menu/play screen in our Apple Silicon macOS 27 test, while DXMT produced a black screen. Explicit per-game graphics choices take precedence. This is a startup test, not a complete gameplay or online-compatibility certification.

Neutron uses its own app identity (`us.flymedia.neutron`) and support directory (`~/Library/Application Support/neutron`). The Highball engine remains in Highball's standard shared folder. Existing prefix marker names and upstream engine IDs are retained for compatibility. Install only one Steam integration at a time; use the existing integration's removal flow before switching. Keep prefix backups and saves.

## Upstream maintenance

NotProton is the direct code base and primary upstream. The initial Neutron feature commit sits on NotProton 1.1.9 (`d5c6065`), including its focus and VC++ runtime fixes. Highball support is a separate import recorded in `UPSTREAMS.json`; Neutron does not wait for or automatically merge the rest of Proton-ish. Full NotProton history is retained. Set up the optional local remotes with:

```sh
git remote add upstream https://github.com/NotProtonNot/NotProton.git
git fetch --all
```

The **upstream sync** workflow runs daily and on demand. It proposes merges directly from NotProton as pull requests, reports conflicts as issues, refreshes pinned HighballKit/highball-db, and reports newer engine builds that need hash/detour validation. It never merges or releases automatically. Brand, filesystem and runtime checks must pass before incorporating upstream changes.

It uses the repository's `GITHUB_TOKEN`. When repository and organization policy permit bot-created PRs, it opens PRs directly. If GitHub refuses PR creation, it keeps the prepared branch and opens an issue linking its comparison page for a manual PR; CI still runs on that branch. No organization policy changes are needed for this fallback. To permit direct PR creation, enable **Allow GitHub Actions to create and approve pull requests** in repository settings (subject to organization policy). A `SYNC_TOKEN` is optional for organizations with different bot policies. Checks for token-created PRs are explicitly dispatched so GitHub's event suppression does not silently skip CI. New engine builds require manual verification before use.

## Build and test

See [BUILDING.md](BUILDING.md) for Fly Media signing and [SECURITY.md](SECURITY.md) for repository protections and private security reports. Original component notices are included in every app bundle; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Use Xcode 27 or newer. The build pins HighballKit and engine manifests; do not substitute engine files without updating the verified hashes and detours.

```sh
brew install cmake shellcheck node mingw-w64 bison flex fontforge gpatch
git clone https://github.com/jmpews/Dobby.git vendor/dobby
git -C vendor/dobby checkout 5dfc8546954ce3b3198132ab13fddb89ee92cdd7
make dobby all overlay-shim iconmaker appinfo bridge
# Font generation also needs the pinned Python packages used in .github/workflows/app.yml.
make fonts app
# On a configured Fly Media Mac, require the company signing identity:
make app-flymedia
make app-tests seedcheck envcheck settingscheck bridgecheck gamedrivecheck launchercheck brandcheck synccheck
```

The full app workflow builds and packages `Neutron.zip`. The release workflow is an explicit manual dispatch and publishes prereleases only. Neutron does not reuse another publisher's update-signing key or Homebrew tap.

## Changes from upstream

- 2026-10-16: Alpha 2 removes unused paid-engine status/setup code and unnecessary branding in dialogs and the Steam UI; bundles original notices and source references; verifies Fly Media signing for local builds; pins CI actions and protects main through PRs and required checks.

- 2026-10-16: Fly Media Neutron identity, Highball-only guided setup, removal of funding/purchase prompts and paid-engine choices, explicit Neutron updates, direct NotProton sync, exFAT prefix fixes, complete Highball template environment, and the tested Tetris Effect renderer default.

## License and credits

Neutron modifications are GPLv3. See [NOTICE](NOTICE), [LICENSE](LICENSE), and the component licenses for upstream authorship and third-party terms. Required notices are preserved. Some runtime components have separate licenses, including Apple's optional D3DMetal agreement. Wine engine identifiers reflect their upstream artifacts; they are not product recommendations.
