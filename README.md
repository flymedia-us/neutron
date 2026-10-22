# Neutron

Proton for macOS. Play Windows Steam games like they're Mac native. Free and powered by [Highball](https://github.com/gauthierpiarrette/highball).

[**Download the latest release**](https://github.com/flymedia-us/neutron/releases/latest)

## Get started

Requires an Apple silicon Mac, macOS 15 or later, Steam for macOS, and Rosetta 2.

1. Open the **DMG** and drag **Neutron** into **Applications**.
2. Open Neutron and choose **Set Up Neutron**. Allow App Management when prompted. Setup installs the engine and Steam integration; no separate Highball app is needed.
3. Choose **Open Steam** and play. For games with a native Mac version, select Neutron's Highball tool in **Properties → Compatibility** to play the Windows version.

Official releases are signed and notarized. Neutron checks for updates automatically; use **Check for Updates…** to install a verified update. D3DMetal is optional and requires accepting Apple's license during setup. Compatibility varies by game.

## Libraries and game settings

Add an existing exFAT library in **Steam → Settings → Storage** and reconnect the drive before playing. Use Steam Cloud for saves between computers, allowing each computer to finish syncing before switching. Sharing a library does not provide universal offline save sharing.

Most games can use **Automatic** settings. For tuning, open **Steam → game Properties → Compatibility → Neutron game settings**. Renderer, display, Windows UI scale, frame rate, and controller options are available; explicit choices take precedence over database recommendations.

See the [usage guide](docs/USAGE.md) for external drives, saves, graphics options, and troubleshooting.

## Development

- [Build and test](BUILDING.md)
- [Releases and automatic updates](RELEASING.md)
- [Upstream maintenance](docs/UPSTREAM.md)
- [Report a bug](https://github.com/flymedia-us/neutron/issues/new/choose) · [Report a security issue](SECURITY.md)

## Changes from upstream

Neutron adds guided Highball setup, external-library fixes, per-game settings, and independent updates. See the [change history](CHANGELOG.md) and [pinned upstreams](UPSTREAMS.json).

## Credits and license

Neutron by Fly Media is a fork of NotProton by [NotProtonNot](https://github.com/NotProtonNot/NotProton), with Highball integration adapted from [Proton-ish](https://github.com/MagnusPladsen/Proton-ish). It uses HighballKit and [highball-db](https://github.com/gauthierpiarrette/highball-db). Neutron is not affiliated with or endorsed by these projects, Valve, or Apple.

Neutron modifications are GPLv3; components retain their own licenses. See [LICENSE](LICENSE), [NOTICE](NOTICE), and [third-party notices](THIRD_PARTY_NOTICES.md).
