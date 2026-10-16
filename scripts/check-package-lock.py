#!/usr/bin/env python3
"""Reject unreviewed dependency changes; SwiftPM may refresh originHash/formatting."""
import json
import pathlib
import subprocess
import sys

path = 'app/Package.resolved'
before = json.loads(subprocess.check_output(['git', 'show', 'HEAD:' + path], text=True))
after = json.loads(pathlib.Path(path).read_text())
if before['pins'] != after['pins']:
    sys.exit('Dependency pins changed during the build. Review and commit the resolved graph before merging.')
print('Dependency pins match the reviewed source revision.')
