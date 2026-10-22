# Changes from upstream

Neutron modification and integration history. See [UPSTREAMS.json](UPSTREAMS.json) for the pinned sources.

- 2026-10-22: Refresh highball-db to `a5fbc49` (540 games / 39 recipes), incorporating the latest compatibility reports and game entries. HighballKit remains at 0.10.22 and the verified runtime remains r19; newer engine integration is tracked separately.

- 2026-10-22: Alpha 6 checks access before updating Steam. When App Management permission is needed, setup opens a guided prompt, remembers the requested setup, and resumes once after relaunch before reporting a permission failure.

- 2026-10-22: Restore Steam Auto-Cloud Windows save-folder mapping for Highball games, including Spider-Man Remastered. Migrate existing Highball tool selections without rebuilding prefixes or removing saves.

- 2026-10-21: Alpha 5 incorporates NotProton through `730f100`: prefix rebuilds from Steam with progress and backup choices, same-architecture build switching, recovery after an early crash, AVX2 defaults, reduced x87 precision controls, game-title parsing and Italian translations. Update HighballKit to 0.10.22 and the game database to 523 games / 39 recipes. Preserve Neutron’s Highball, external-drive and display settings. Release CI checks credentials before compiling.

- 2026-10-19: Integrate NotProton 1.2.0 (`2791679`), including Windows library filters, non-Steam shortcuts, prefix locking, download deadlines, external Steam verification, overlay ownership, and controller fixes. Keep Highball and external-library support; align Advanced sections; add signed in-app updates and automated notarized GitHub releases. Neutron retains explicit DPI settings instead of upstream’s automatic DPI doubling.

- 2026-10-16: Alpha 4 keeps library management in Steam and adds collapsed per-game display, Windows UI scaling and supported frame-limit controls. Automatic exposes native display modes; explicit scaled-mode preferences remain supported.

- 2026-10-16: Alpha 3 simplifies Home into guided setup, readiness checks, Open Steam, and visible external-library status; moves maintenance into Advanced; checks Rosetta before setup and fixes Windows-game defaults on the first Steam launch.

- 2026-10-16: Alpha 2 removes unused paid-engine status/setup code and unnecessary branding in dialogs and the Steam UI; bundles original notices and source references; verifies Fly Media signing for local builds; pins CI actions and protects main through PRs and required checks.

- 2026-10-16: Fly Media Neutron identity, Highball-only guided setup, removal of funding/purchase prompts and paid-engine choices, explicit Neutron updates, direct NotProton sync, exFAT prefix fixes, complete Highball template environment, and the tested Tetris Effect renderer default.

