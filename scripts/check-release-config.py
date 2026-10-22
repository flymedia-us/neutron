#!/usr/bin/env python3
"""Fail before a release build when required credentials are absent or malformed."""
import base64
import os
import sys


NAMES = (
    'DEVELOPER_ID_P12_BASE64', 'DEVELOPER_ID_P12_PASSWORD',
    'APP_STORE_CONNECT_API_KEY', 'APP_STORE_CONNECT_KEY_ID',
    'APP_STORE_CONNECT_ISSUER_ID', 'SPARKLE_PRIVATE_KEY', 'SPARKLE_PUBLIC_KEY',
)


def errors(environment):
    missing = [name for name in NAMES if not environment.get(name, '').strip()]
    result = ['Missing release configuration: ' + name for name in missing]
    for name, sizes in [('DEVELOPER_ID_P12_BASE64', None),
                        ('SPARKLE_PRIVATE_KEY', (32, 96)), ('SPARKLE_PUBLIC_KEY', (32,))]:
        if name in missing:
            continue
        try:
            value = base64.b64decode(''.join(environment[name].split()), validate=True)
            if not value or (sizes and len(value) not in sizes):
                raise ValueError()
        except ValueError:
            result.append('Invalid release configuration format: ' + name)
    key = environment.get('APP_STORE_CONNECT_API_KEY', '').strip()
    if key and not (key.startswith('-----BEGIN PRIVATE KEY-----') and key.endswith('-----END PRIVATE KEY-----')):
        result.append('APP_STORE_CONNECT_API_KEY must contain the raw .p8 text, not base64.')
    return result


if __name__ == '__main__':
    problems = errors(os.environ)
    if problems:
        print('\n'.join(problems), file=sys.stderr)
        sys.exit(1)
    print('Release configuration is present; signing verifies the certificate and update key pair.')
