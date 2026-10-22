#!/usr/bin/env python3
"""Write changelog-only GitHub notes, comparing published app versions."""
import argparse
import json
import pathlib
import re
import subprocess

REPOSITORY = 'flymedia-us/neutron'
VERSION_TAG = re.compile(r'v\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)\.\d+)?')


def previous_release(tag, releases):
    """Find the closest published ancestor; ignore the feed and inherited tags."""
    candidates = []
    for release in releases:
        previous = release['tag_name']
        if release['draft'] or previous == tag or not VERSION_TAG.fullmatch(previous):
            continue
        # Full refs also prevent an API-supplied tag from being interpreted as an option.
        ref = f'refs/tags/{previous}'
        ancestor = subprocess.run(['git', 'merge-base', '--is-ancestor', ref, f'refs/tags/{tag}'],
                                  capture_output=True)
        if ancestor.returncode == 1:
            continue
        ancestor.check_returncode()
        distance = int(subprocess.check_output(['git', 'rev-list', '--count', f'{ref}..refs/tags/{tag}']))
        if distance:
            candidates.append((distance, previous))
    return min(candidates)[1] if candidates else None


def release_notes(tag):
    if not VERSION_TAG.fullmatch(tag):
        raise ValueError('Expected a Neutron version tag.')
    pages = json.loads(subprocess.check_output([
        'gh', 'api', f'repos/{REPOSITORY}/releases', '--paginate', '--slurp',
    ], text=True))
    previous = previous_release(tag, [release for page in pages for release in page])
    if previous is None:
        return f'Initial Neutron release.\n\n**Full Changelog**: https://github.com/{REPOSITORY}/commits/{tag}\n'
    result = json.loads(subprocess.check_output([
        'gh', 'api', '--method', 'POST', f'repos/{REPOSITORY}/releases/generate-notes',
        '-f', f'tag_name={tag}', '-f', f'previous_tag_name={previous}',
    ], text=True))
    return result['body'].strip() + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tag')
    parser.add_argument('output', type=pathlib.Path)
    args = parser.parse_args()
    args.output.write_text(release_notes(args.tag))


if __name__ == '__main__':
    main()
