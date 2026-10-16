# Contributing to Neutron

Neutron is Fly Media's Highball-only fork of NotProton. Its Highball integration was adapted from Proton-ish. Retain upstream attribution and licenses. Work on branches and send pull requests here.

Keep upstream merges reviewable. Preserve internal `np_`/`NP_` symbols, Swift module names, prefix marker formats, and exact upstream engine IDs unless a migration is implemented. Neutron's product name, app identifier, support paths and update destination must remain its own.

Run the relevant tests and `make brandcheck`. User-visible changes get a dated entry in README.md. Check external filesystems as well as APFS when changing prefix handling. Never remove saved games while repairing a prefix.

The UI offers only the free Highball runtime. Do not reintroduce purchase prompts, donation nags, paid-engine setup or another publisher's update-signing key through an upstream merge. Legacy internal adapters may remain to keep upstream changes mergeable, but are not part of Neutron's setup flow.

Upstream synchronization opens reviewable PRs or conflict issues; it never merges automatically. Releases are explicit and require a successful full build. Tests that touch Steam or the filesystem must use fixtures instead of the real user installation.
