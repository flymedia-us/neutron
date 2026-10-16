#!/bin/sh
set -eu
cd "$(git rev-parse --show-toplevel)"
python3 - <<'CHECK'
from pathlib import Path
import plistlib
r=Path('.')
info=plistlib.loads((r/'app/Info.plist').read_bytes())
assert info['CFBundleName']=='Neutron'
assert info['CFBundleIdentifier']=='us.flymedia.neutron'
assert 'SUPublicEDKey' not in info, 'Do not trust another publisher for Neutron updates'
app=r/'app/Sources/NotProtonApp'
for p in [app/'App.swift', app/'SystemStatus.swift', app/'PrefixesModel.swift', app/'Model/PrefixPrompt.swift', *list((app/'Views').glob('*.swift')), r/'dylib/feats/webpatch.c', r/'.github/ISSUE_TEMPLATE/bug_report.yml']:
    s=p.read_text()
    for forbidden in ['CrossOver','FundingNotice','Why Buy','Support CodeWeavers','Proton-ish']:
        assert forbidden.lower() not in s.lower().replace('x64-crossover', 'x64-runtime'), f'{p}: product UI contains {forbidden}'
assert 'supportDirName = "neutron"' in (app/'Support/SupportPaths.swift').read_text()
assert 'fork of NotProton' in (r/'README.md').read_text()
assert 'Fly Media' in info['NSHumanReadableCopyright']
assert 'MagnusPladsen/Proton-ish' in (r/'NOTICE').read_text()
print('==> brandcheck: Neutron identity, Highball-only UI, attribution and update trust verified')
CHECK
