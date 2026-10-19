#!/usr/bin/env python3
"""Embed only the public update key; unsigned contributor builds leave updates off."""
import argparse
import base64
import os
import pathlib
import plistlib


def configure(path, public_key):
    info = plistlib.loads(path.read_bytes())
    if public_key:
        try:
            valid = len(base64.b64decode(public_key, validate=True)) == 32
        except ValueError:
            valid = False
        if not valid:
            raise ValueError('SPARKLE_PUBLIC_KEY must be a base64 Ed25519 public key (32 bytes).')
        info['SUPublicEDKey'] = public_key
        info['SUEnableAutomaticChecks'] = True
    else:
        info.pop('SUPublicEDKey', None)
        info['SUEnableAutomaticChecks'] = False
    path.write_bytes(plistlib.dumps(info))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plist', type=pathlib.Path)
    args = parser.parse_args()
    configure(args.plist, os.environ.get('SPARKLE_PUBLIC_KEY', '').strip())
