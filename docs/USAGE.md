# Using Neutron

[Back to README](../README.md)

## Set up

You need an Apple Silicon Mac, macOS 15 or later, Steam for macOS, and Rosetta 2.

1. Download the **Neutron DMG** from [Releases](https://github.com/flymedia-us/neutron/releases), open it, and drag **Neutron** into **Applications**.
2. Open Neutron. Official releases use Fly Media Developer ID signing and Apple notarization. Development and Actions artifacts are ad hoc signed and may require **Privacy & Security → Open Anyway**. Allow App Management when requested, because Neutron patches Steam.
3. On **Home**, click **Set Up Neutron**. Setup closes Steam for you. If prompted, read Apple's D3DMetal license and choose whether to accept it. A previously accepted license is reused. Neutron installs the Steam integration, downloads or reuses Highball's engine, verifies its downloads, and selects its compatibility tool as the Windows-game default on first setup. Later repairs preserve your explicit default-tool choice. No separate Highball app is needed.
4. When Home says **You're ready to play**, click **Open Steam**. Windows-only games show Play. For a game with a native Mac version, select Neutron's Highball tool under **Properties → Compatibility** to use the Windows version.

The download is about 440 MB plus any missing Steam components. D3DMetal is optional and is used only after Apple's license is accepted. Without it, DXMT/DXVK are available, but games requiring D3DMetal will not work. Official builds check Neutron's GitHub update feed automatically. **Check for Updates…** downloads and installs verified updates in the app; automatic installation is optional in Sparkle's update window. Stable builds receive stable versions; alpha/beta/RC builds also receive previews. Source builds without the public update key have background update checks disabled. Existing builds whose update command only opens GitHub need one manual install of an updater-enabled official release.

## External and portable libraries

Keep your Windows Steam library on the existing exFAT drive and add that same library in **Steam → Settings → Storage** on each computer. Reconnect the drive before playing. If macOS asks for access to removable volumes when a game starts, allow it so the game can read its external files. Manage libraries and drives directly in Steam; Neutron handles the compatibility work in the background. Generated launcher settings are stored locally with the game launcher. Neutron handles macOS AppleDouble metadata and copies prefix files when the drive rejects hard links. Highball's template creation receives the engine's library paths. These fixes are embedded in Neutron; no launcher patch needs to be reapplied after restarting Steam.

The game payload and Mac Wine prefixes can stay on the drive. Steam, Neutron, the engine, permissions, and prerequisites still need setup on each host. A drive cannot make every Windows game compatible with every Mac. DRM, other launchers, anti-cheat, and game-specific save locations can limit portability. This exFAT behavior was tested on macOS 27; other filesystem drivers can differ. Do not reformat an existing drive to try Neutron.

**Saves between computers:** Neutron runs the Windows game and preserves its save files without converting their format. For games with compatible Steam Cloud support, use the same Steam account and enable Cloud on each computer. Close the game and wait for Steam to finish syncing before ejecting the drive; let the next computer finish syncing before playing. Windows normally keeps Documents/AppData saves in that computer's user profile, while Neutron uses `steamapps/compatdata/<appid>/pfx/drive_c/users/steamuser/` in the game's library. Sharing the game installation does not automatically make these the same physical save folder. Universal offline save sharing is not implemented. Cloud configuration and save compatibility remain game-specific; see [Valve's cross-platform Cloud documentation](https://partner.steamgames.com/doc/features/cloud).

**Linux:** Neutron is a macOS integration. Shared Windows game files do not make its Mac Wine prefix a supported Linux Proton prefix. Proton has [known exFAT compatibility-data limitations](https://github.com/ValveSoftware/Proton/issues/3835), so Linux needs its own compatible prefix/filesystem setup and validation. When sharing an installation, keep using the Windows version of the game through Neutron or Proton; selecting a native Mac/Linux build can change the downloaded game files and save behavior. This release does not certify interchangeable prefixes or offline saves across all three operating systems.

**Tetris Effect: Connected (1003590):** Automatic uses D3DMetal when available; this reached a visible menu/play screen in our Apple Silicon macOS 27 test, while DXMT produced a black screen. Explicit per-game graphics choices take precedence. This is a startup test, not a complete gameplay or online-compatibility certification.

Neutron uses its own app identity (`us.flymedia.neutron`) and support directory (`~/Library/Application Support/neutron`). The Highball engine remains in Highball's standard shared folder. Existing prefix marker names and upstream engine IDs are retained for compatibility. Install only one Steam integration at a time; use the existing integration's removal flow before switching. Keep prefix backups and saves.

## Per-game settings

Most games can use Automatic. It applies the bundled Highball database's renderer recommendations and supported launch-environment recipe steps when a matching entry exists. Explicit graphics choices and launch-option overrides take precedence. The bundled compatibility snapshot is refreshed through upstream maintenance. Database status is compatibility evidence, not a guarantee of optimal performance on every Mac. Recipe installers, registry edits, Winetricks, file operations and launch-argument injection are not applied automatically.

For troubleshooting or tuning, open **Steam → game Properties → Compatibility → Neutron game settings**. These controls start collapsed:

- **Display pixels:** Automatic exposes native/Retina display modes. Choose scaled desktop pixels to use macOS's logical display sizes instead. Existing explicit High Resolution off choices remain off.
- **Windows UI scale:** 100–250%, for launchers and Windows UI. Larger UI uses native pixels. Full-screen games may ignore Windows UI scaling.
- **Frame rate limit:** available with explicit DXMT or DXVK; advanced renderer variables take precedence. With this engine's D3DMetal version, use the game's own frame limiter.
- Graphics renderer, Metal HUD, DLSS, MetalFX upscaling, MSync and controller behavior remain available.

Choose the actual render resolution (such as 1920 × 1080 or 3840 × 2160) inside the game. A 4K monitor can have a different scaled macOS desktop size; these are different measurements. Native pixels make full-resolution modes available but do not overwrite a game's saved resolution. Higher render resolutions require more GPU work. Changes take effect at the next launch.

