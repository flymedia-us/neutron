#!/usr/bin/env python3
"""Upload an existing AppleTree/Fly Media notary API key to Neutron's release environment."""
import argparse
import pathlib
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('key_file', type=pathlib.Path, help='Original App Store Connect .p8 file')
    parser.add_argument('--key-id', required=True)
    parser.add_argument('--issuer-id', required=True)
    args = parser.parse_args()
    key = args.key_file.read_bytes()
    if not key.strip().startswith(b'-----BEGIN PRIVATE KEY-----'):
        parser.error('Use the original .p8 file, not a base64 encoding.')
    checked = subprocess.run(['openssl', 'pkey', '-check', '-noout'], input=key, capture_output=True)
    if checked.returncode:
        parser.error('The .p8 file is not a valid private key.')
    for name, value in [
        ('APP_STORE_CONNECT_API_KEY', key),
        ('APP_STORE_CONNECT_KEY_ID', args.key_id.encode()),
        ('APP_STORE_CONNECT_ISSUER_ID', args.issuer_id.encode()),
    ]:
        subprocess.run(['gh', 'secret', 'set', name, '--repo', 'flymedia-us/neutron',
                        '--env', 'release'], input=value, check=True)
        print('Configured ' + name)
    print('Apple API credentials configured. Push a reviewed version tag to build and notarize.')


if __name__ == '__main__':
    main()
