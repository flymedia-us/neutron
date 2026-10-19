# Alpha 4 local validation

Validated on the development Mac on October 16, 2026.

- Swift tests: 570 app tests and 44 Highball environment tests passed.
- `make panel-behavior settingscheck runcheck envcheck gamedrivecheck launchercheck brandcheck`: passed.
- Panel tests exercise both Steam UI injection forms, collapsed settings, native/scaled modes, Windows UI scaling, supported FPS caps, custom values, resets, renderer switching, localization, and preservation of launch arguments.
- Settings tests verify actual registry imports, safe DPI fallback, explicit scaled-mode preservation, native modes by default, fresh Wine sessions after imports, and unchanged controller ownership behavior.
- Real installed Highball engine: the bundled database selected D3DMetal for a matching game; an explicit DXMT selection took precedence, and the 60 FPS limit reached DXMT's environment.
- `make app-flymedia`: built alpha 4 and the ZIP; all eight Mach-O files and the app were signed and verified for Fly Media team BJZSH247Q9.
- Installed at `/Applications/Neutron.app`, preserving the previous app in `/private/tmp`. The installed and packaged app both passed strict, deep signature verification with the system signing services available.
- Guided setup updated the local Steam integration to alpha 4, verified all 19 payload components and the engine, and reached the ready state. Home has no library or drive list; Advanced starts collapsed.

Live Steam checks:

- Steam started with alpha 4, loaded the patched Compatibility UI, and applied the Windows-game default.
- Tetris Properties shows Neutron game settings collapsed. Expanding it displays renderer, native/scaled pixel, Windows UI scaling and existing expert controls correctly.
- Switching Display pixels to Scaled saved the preference; restoring Automatic removed that override and preserved the original D3DMetal launch option.
- Tetris's external exFAT prefix was created and seeded, its registry contains RetinaMode=y and LogPixels=96, and the launch helper selected D3DMetal. Steam's first-time prerequisite installer completed successfully. The game loader then encountered removable-volume access restrictions before reaching its window.
- macOS reports the main display as 2304 × 1296 logical points with a 4608 × 2592 backing surface. This difference can explain unexpected resolution numbers; it is not proof of the panel's physical resolution or Tetris's previous configuration.

The live drive test exposed a shell read of the generated graphics environment from the external prefix. That configuration is now copied into the local launcher bundle; an added launcher regression test proves the copy remains usable when the original file is unavailable. `make envcheck runcheck launchercheck` passed after this fix.

The user allowed removable-drive access. Tetris then started its Win64 shipping executable and initialized its Metal rendering pipelines. The user subsequently confirmed that Tetris reached its menu. This establishes a successful external-drive launch to the menu for the initial alpha 4 build; gameplay and exact resolution were not verified.

The corrected app was installed and passed strict signature verification. Guided setup deployed the corrected launcher and again reached the ready state. A fresh Steam launch generated the local `Contents/Resources/highball.env` reference, with no external-settings read error. This launch initially waited in a macOS file-open call, then started the Win64 game and initialized the Metal render pipelines. The user confirmed allowing the additional removable-drive prompt and reported that the game was opening. The computer-use tool cannot attach to the Wine game window and denies access to UserNotificationCenter for safety reasons. No privacy grants were changed by the agent. The game was left running.

Exact Tetris resolution and gameplay validation remain pending. The corrected build's final menu was not independently observed. Automated and launch-environment checks do not certify gameplay.

This is a development-signed local build, not a notarized public release.

Final ZIP SHA-256: `206d4eba6bb3e051c63325987a06443563a092d1dd3b9bc59953d1eb0922d91f`.
