#!/usr/bin/env python3
"""Validate release tags and produce a Sparkle item without exposing private keys."""
import argparse
import base64
import datetime
import json
import pathlib
import plistlib
import re
import subprocess
import xml.etree.ElementTree as ET

SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', SPARKLE)
REPOSITORY = 'flymedia-us/neutron'


def version_from_source():
    text = pathlib.Path('dylib/version.h').read_text()
    match = re.search(r'^#define NOTPROTON_VERSION "([^"]+)"$', text, re.M)
    if not match or not re.fullmatch(r'\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)\.\d+)?', match[1]):
        raise ValueError('Expected a semantic version, optionally suffixed -alpha.N, -beta.N or -rc.N.')
    return match[1]


def release_item(info, archive, signature):
    version = info['CFBundleShortVersionString']
    if len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError('Invalid Ed25519 archive signature.')
    item = ET.Element('item')
    ET.SubElement(item, 'title').text = f'Neutron {version}'
    ET.SubElement(item, 'link').text = f'https://github.com/{REPOSITORY}/releases/tag/v{version}'
    for key, value in [('version', info['CFBundleVersion']), ('shortVersionString', version),
                       ('minimumSystemVersion', '15.0.0'), ('hardwareRequirements', 'arm64')]:
        ET.SubElement(item, f'{{{SPARKLE}}}{key}').text = value
    if '-' in version:
        ET.SubElement(item, f'{{{SPARKLE}}}channel').text = 'preview'
    ET.SubElement(item, 'pubDate').text = datetime.datetime.now(datetime.timezone.utc).strftime('%a, %d %b %Y %H:%M:%S +0000')
    ET.SubElement(item, 'description').text = f'Neutron {version}. Release notes and source are available on GitHub.'
    ET.SubElement(item, 'enclosure', {
        'url': f'https://github.com/{REPOSITORY}/releases/download/v{version}/Neutron.zip',
        f'{{{SPARKLE}}}edSignature': signature,
        'length': str(archive.stat().st_size), 'type': 'application/octet-stream',
    })
    return item


def merge_feed(item, previous=None):
    rss = ET.Element('rss', {'version': '2.0'})
    channel = ET.SubElement(rss, 'channel')
    ET.SubElement(channel, 'title').text = 'Neutron updates'
    ET.SubElement(channel, 'link').text = f'https://github.com/{REPOSITORY}/releases'
    ET.SubElement(channel, 'description').text = 'Signed Neutron releases from Fly Media'
    items = [item]
    if previous is not None:
        items.extend(previous.findall('./channel/item'))
    seen = set()
    for candidate in items:
        build = candidate.findtext(f'{{{SPARKLE}}}version')
        if build and build not in seen:
            channel.append(candidate)
            seen.add(build)
    # Keep the history so stable clients can still see the last stable release
    # after preview builds have been published. Sparkle selects by build number.
    ET.indent(rss)
    return rss


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    validate = sub.add_parser('validate')
    validate.add_argument('tag')
    sub.add_parser('pending-tag')
    item = sub.add_parser('item')
    item.add_argument('app', type=pathlib.Path)
    item.add_argument('archive', type=pathlib.Path)
    item.add_argument('signature')
    item.add_argument('output', type=pathlib.Path)
    feed = sub.add_parser('feed')
    feed.add_argument('item', type=pathlib.Path)
    feed.add_argument('output', type=pathlib.Path)
    feed.add_argument('--previous', type=pathlib.Path)
    args = parser.parse_args()
    if args.command in ('validate', 'pending-tag'):
        version = version_from_source()
        tag = f'v{version}'
        if args.command == 'validate' and args.tag != tag:
            raise ValueError('The release tag must match dylib/version.h exactly.')
        subprocess.run(['git', 'merge-base', '--is-ancestor', 'HEAD', 'origin/main'], check=True)
        if subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip():
            raise ValueError('Releases require a clean source checkout.')
        result = {'version': version, 'prerelease': '-' in version,
                  'build': subprocess.check_output(['git', 'rev-list', '--count', 'HEAD'], text=True).strip()}
        if args.command == 'pending-tag':
            existing = subprocess.run(['git', 'rev-parse', '--verify', f'refs/tags/{tag}^{{commit}}'],
                                      capture_output=True, text=True)
            head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
            result.update(tag=tag, pending=existing.returncode != 0 or existing.stdout.strip() == head)
        print(json.dumps(result))
    elif args.command == 'item':
        info = plistlib.loads((args.app / 'Contents/Info.plist').read_bytes())
        ET.ElementTree(release_item(info, args.archive, args.signature)).write(args.output, encoding='utf-8', xml_declaration=True)
    else:
        previous = ET.parse(args.previous).getroot() if args.previous else None
        ET.ElementTree(merge_feed(ET.parse(args.item).getroot(), previous)).write(args.output, encoding='utf-8', xml_declaration=True)


if __name__ == '__main__':
    main()
