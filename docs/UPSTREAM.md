# Upstream maintenance

NotProton is the direct code base and primary upstream. Neutron incorporates NotProton 1.2.0 through `730f100` (2026-10-21), with Neutron-specific adaptations to preserve Highball, internal/external libraries, native display modes, and independent Windows UI scaling. The original fork started on 1.1.9 (`d5c6065`). Highball support is a separate import recorded in [UPSTREAMS.json](../UPSTREAMS.json); Neutron does not wait for or automatically merge the rest of Proton-ish. Full NotProton history is retained. Set up the optional local remotes with:

```sh
git remote add upstream https://github.com/NotProtonNot/NotProton.git
git fetch --all
```

The **upstream sync** workflow runs daily and on demand. It proposes merges directly from NotProton as pull requests, reports conflicts as issues, refreshes pinned HighballKit/highball-db, and reports newer engine builds that need hash/detour validation. It never merges or releases automatically. Brand, filesystem and runtime checks must pass before incorporating upstream changes.

It uses the repository's `GITHUB_TOKEN`. When repository and organization policy permit bot-created PRs, it opens PRs directly. If GitHub refuses PR creation, it keeps the prepared branch and opens an issue linking its comparison page for a manual PR; CI still runs on that branch. No organization policy changes are needed for this fallback. To permit direct PR creation, enable **Allow GitHub Actions to create and approve pull requests** in repository settings (subject to organization policy). A `SYNC_TOKEN` is optional for organizations with different bot policies. Checks for token-created PRs are explicitly dispatched so GitHub's event suppression does not silently skip CI. New engine builds require manual verification before use.

Record dated integration notes in [CHANGELOG.md](../CHANGELOG.md), keeping the README focused on getting started.
