# Steam Auto-Cloud repair — 2026-10-22

Spider-Man Remastered (1817070) launched successfully but offered a fresh game.
Steam client 1792192922 logged `Unable to resolve path with root WinMyDocuments`,
watched zero save files, and skipped the Auto-Cloud rule on exit. Its cloud
revision remained 7; that session recorded no Spider-Man save uploads.

The arm64 client's tool registration code at `0x6c0bec` reads the tool name
at offset `0x40`, calls `V_stristr(name, "proton")`, and initializes the Windows
Cloud root strings only on a match. `compatmanager_layer_name` is a separate
manifest field and does not satisfy this check. Neutron's branding removed the
required substring from its Highball tool ID.

The corrected ID is `neutron-proton-highball-x64-crossover26.3-r19`. Engine IDs,
prefixes, and display names stay the same. The dylib migrates the exact previous
Highball ID in global and per-game mappings once the replacement is registered.
Old default request files remain readable. Foreign choices, explicit opt-outs,
and unavailable replacements are left alone.

Recovery preserved separate copies of the old Documents saves, the fresh-start
profile, Steam's cache, and the logs. All 21 old save files matched the hashes
in the Steam cloud cache, including slots 0, 1, and 2. They were restored with
timestamps preserved, and every hash was checked after copying to the external
exFAT Steam library. Fresh-start files were retained outside the watched folder.
No save was deleted. Personal recovery files are outside the repository.

After installing the signed app/integration and restarting Steam, its log
reported all 21 Spider-Man files `File is in sync`; the server cloud revision
stayed 7. The local cache revision is 0 pending a full sync on the next launch.
The repaired profile's hashes were checked again after Steam restarted. Tetris
Effect's working Auto-Cloud rule uses `GameInstall`, explaining why it was
unaffected by the Windows Documents mapping failure. This verification did not
start a new gameplay session or advance a save.

Validation:

- `make compatcheck brandcheck panel-behavior` passed, including global/per-game
  migration, repeated migration, absent replacements, legacy requests and
  unrelated tool choices.
- 66 focused Swift tests in eight suites passed: default-tool migration, tool
  identity/cloud invariant, runtime, onboarding, cloning, runner switching and
  Steam compatibility configuration.
- `make dylib` and `make APP_REQUIRE_TEAM=1 app` passed. App signatures verified
  with strict/deep validation outside the restricted compiler sandbox; installed
  app executable matched the built executable. Neutron reported the installed
  Steam integration and engine verified/current.
- `git diff --check` passed.
