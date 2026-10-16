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
for p in [app/'App.swift', *list((app/'Views').glob('*.swift'))]:
    s=p.read_text()
    for forbidden in ['CrossOver','FundingNotice','Why Buy','Support CodeWeavers','Proton-ish']:
        assert forbidden not in s, f'{p}: product UI contains {forbidden}'
assert 'supportDirName = "neutron"' in (app/'Support/SupportPaths.swift').read_text()
assert 'fork of NotProton' in (r/'README.md').read_text()
assert 'MagnusPladsen/Proton-ish' in (r/'NOTICE').read_text()
print('==> brandcheck: Neutron identity, Highball-only UI, attribution and update trust verified')
CHECK
