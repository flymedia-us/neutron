# Ease of use and onboarding

The first screen should answer three questions: Is my Mac ready? What happens when I click setup? How do I play?

## Implement in this pass

- One primary setup action and a readiness checklist; move component details, update blocking, controller reset, and destructive maintenance into Advanced.
- Explain that setup closes Steam, reuses an existing engine, and may request App Management permission. Keep Apple's optional graphics license an explicit choice; skip asking again when already accepted.
- Keep the entire guided operation busy, check Rosetta before modifying Steam, and report a default-tool write failure instead of silently claiming success.
- Configure the Windows-game default explicitly on first guided setup, including when patched Steam has never run; preserve an existing explicit Neutron preference.
- Derive readiness from actual integration, payload, engine and tool state, rather than a saved “onboarded” flag. Finish with Open Steam and short launch instructions.
- Keep storage management in Steam. Home has no library paths, counts or drive diagnostics. External-drive compatibility stays in the launcher.
- Use approachable sidebar names while retaining precise technical wording in advanced tools and backup warnings.

## Validation

Build with the existing Fly Media signing target; verify the team signature. Run Swift tests and relevant native checks. Exercise the first-run screen, setup, ready state, external library detection and actual external-game launch on this Mac. Do not claim gameplay compatibility from a successful launch alone.

## Follow-up distribution work

Developer ID signing and notarization remain necessary for a public download without Gatekeeper friction; this Mac currently uses Fly Media's development certificate. A larger compatibility catalog and per-game troubleshooting require separate game testing.

## Per-game customization

Keep casual use at Automatic, with power controls collapsed in Steam's Compatibility properties. Add native/scaled display modes, separate Windows UI scaling, and frame limits for the renderers supported by the bundled engine. Render resolution stays in each game's own options, since arbitrary per-game resolution arguments cannot safely be generalized. Existing explicit choices override automatic behavior.

Highball DB is already bundled and used on each matching game launch. It supplies renderer recommendations and supported environment, DLL and DXVK recipe tweaks. Prefix-changing and installer recipe steps remain explicitly unsupported; database guidance must not be presented as a universal performance guarantee.
