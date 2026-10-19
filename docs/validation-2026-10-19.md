# Upstream, settings and release validation — October 19, 2026

The checkout incorporates NotProton 1.2.0 through
`2791679` with Neutron adaptations. The preexisting guided setup, Highball,
external-library and display changes were retained.

- 592 application tests and 44 Highball environment tests passed.
- After synchronizing the catalog, all four localization lookup tests passed.
  The catalog check covers 475 strings; 43 explicit translation placeholders
  retain English fallback, including inherited and fork-specific help text.
- Native checks passed: signature database, call patterns, Steam library
  filters, appinfo platform detection, PE icons, spawn environment, activation,
  compatibility mappings, compatibility service, shortcuts, launch shell,
  environment, build selection, prefix settings, routing, bridge mapping,
  internal/external game drives and launchers.
- Both Steam panel injection forms passed behavior tests, including renderer
  switching, display controls, controllers, launch arguments, locale selection,
  migration and engine capability limits.
- Overlay tests: eight passed across ARM64 and x86_64, including the upstream
  pipeline ownership and lifetime fixes.
- A clean rebuild of the pinned Wine/Steam bridge passed for the i386/x86_64 Windows DLLs, both Unix architectures, and the Steam helper. The final ZIP includes these fresh binaries.
- The app built with embedded Sparkle and passed strict, deep ad hoc signature
  verification. All 13 Mach-O binaries met the macOS 15 deployment target.
- The expanded Advanced screen was inspected in the running app. Steam,
  Highball, components and maintenance use aligned top-level form sections.
- Five release metadata/configuration regressions passed, including clean-main, wrong-tag, dirty-source and unreviewed-commit checks. Release scripts passed
  ShellCheck and syntax checks; workflow YAML parsed. Swift verified a signed
  archive fixture and rejected the same fixture after tampering.
- Dependency pins matched the committed lockfile. Upstream sync regressions
  cover adapted source pins as well as normal merges, conflicts and bot-policy
  fallback.

Public notarization and an actual update between two published releases cannot
be exercised until the Fly Media Developer ID identity, notary credentials and
Neutron update key are configured. The local Keychain had an Apple Development
identity, with no valid Developer ID Application identity; repository release
secrets were absent. The GitHub `release` environment was created and restricted
to `v*` tags. No public release was published. See `RELEASING.md`.

AppleTree comparison confirmed the shared five Apple secret names and raw `.p8`
format. AppleTree’s GitHub build intentionally has no updater; only Neutron
uses Sparkle. Existing AppleTree release runs succeeded with its current keys.
