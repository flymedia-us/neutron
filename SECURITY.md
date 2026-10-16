# Security policy

Report suspected vulnerabilities privately through
[GitHub private vulnerability reporting](https://github.com/flymedia-us/neutron/security/advisories/new).
Include the affected Neutron version, reproduction steps and impact. Do not put
credentials, personal Steam configuration, private paths or exploit details in a
public issue. General compatibility problems belong in the normal bug template.

The latest published alpha is the supported development version. There is no
guaranteed response time or compatibility promise for older builds.

Changes to `main` go through pull requests and passing build/lint checks. Force
pushes and branch deletion are blocked. This small repository does not currently
require a second maintainer's approval; review is still encouraged. Security rules
have no routine bypass for administrators or synchronization bots.

Upstream synchronization prepares branches for review; it never approves, merges
or releases code. Organization policy may require a human to create the PR from
the comparison link in a sync issue. Use merge commits for NotProton sync PRs so
upstream ancestry is preserved. Releases are manual and limited to `main`.

GitHub Actions use read-only permissions by default and immutable action pins.
Write access is limited to the sync and publish jobs that need it. Pull requests
never receive signing credentials. Apple signing keys stay in the local macOS
keychain and are not committed, exported or uploaded to CI.

Highball downloads and runtime patches are pinned and hash checked. New engine
builds must be validated before use. Neutron changes Steam on the user's Mac;
keep save backups and install only one Steam integration at a time.
