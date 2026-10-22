#!/usr/bin/env python3
"""Release regressions: channel history, update authentication, and local builds."""
import base64
import importlib.util
import json
import os
import pathlib
import plistlib
import subprocess
import shutil
import tempfile
import unittest
from unittest import mock
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / f'{name}.py')
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


metadata = module('release-metadata')
updater = module('configure-updater')
configuration = module('check-release-config')
notes = module('release-notes')


class ReleaseTests(unittest.TestCase):
    def test_changelog_uses_published_ancestor_not_feed_draft_or_upstream_tag(self):
        repo = pathlib.Path(self.work.name) / 'notes-source'
        repo.mkdir()
        def git(*args):
            return subprocess.check_output(['git', '-C', str(repo), *args], text=True).strip()
        git('init', '-q', '-b', 'main')
        git('config', 'user.name', 'Release fixture')
        git('config', 'user.email', 'release@example.invalid')
        tags = ['v0.1.0-alpha.5', 'v1.2.0', 'v0.1.0-beta.1', 'v0.1.0-alpha.6', 'v0.1.0-alpha.7']
        for tag in tags:
            git('commit', '--allow-empty', '-qm', tag)
            git('tag', tag)
        git('tag', 'updates')
        git('checkout', '-q', '--orphan', 'unrelated')
        git('commit', '--allow-empty', '-qm', 'Other history')
        git('tag', 'v9.0.0')
        releases = [{'tag_name': tag, 'draft': tag == 'v0.1.0-beta.1'}
                    for tag in ['updates', 'v9.0.0', *tags] if tag != 'v1.2.0']
        before = os.getcwd()
        os.chdir(repo)
        self.addCleanup(os.chdir, before)
        self.assertEqual(notes.previous_release('v0.1.0-alpha.6', releases), 'v0.1.0-alpha.5')
        self.assertIsNone(notes.previous_release('v0.1.0-alpha.5', releases))
        # Exercise pagination and the exact generated-notes request, preserving
        # real git ancestry checks while substituting only the GitHub API.
        check_output = subprocess.check_output
        calls = []
        def command(args, **kwargs):
            if args[0] != 'gh':
                return check_output(args, **kwargs)
            calls.append(args)
            if 'POST' in args:
                return json.dumps({'body': "## What's Changed\n* Fix Steam Cloud saves.\n"})
            return json.dumps([releases[:2], releases[2:]])
        with mock.patch.object(notes.subprocess, 'check_output', side_effect=command):
            body = notes.release_notes('v0.1.0-alpha.6')
            self.assertIn('Fix Steam Cloud saves.', body)
            self.assertIn('previous_tag_name=v0.1.0-alpha.5', calls[-1])
            self.assertNotIn('Download', body)
            calls.clear()
            first = notes.release_notes('v0.1.0-alpha.5')
            self.assertIn('/commits/v0.1.0-alpha.5', first)
            self.assertEqual(len(calls), 1)

    def test_publish_latest_preview_with_changelog_and_immutable_binaries(self):
        repo = pathlib.Path(self.work.name) / 'publish'
        (repo / 'scripts').mkdir(parents=True)
        (repo / 'release').mkdir()
        for name in ['release-publish.sh', 'release-metadata.py']:
            shutil.copy(ROOT / name, repo / 'scripts' / name)
        (repo / 'scripts/release-notes.py').write_text(
            'import pathlib, sys\npathlib.Path(sys.argv[2]).write_text("## What changed\\n* Fixed saves.\\n")\n')
        for name in ['Neutron.zip', 'Neutron-0.1.0-alpha.6.dmg', 'SOURCE.json']:
            (repo / 'release' / name).write_bytes(b'published fixture')
        import hashlib
        sums = ''.join(f'{hashlib.sha256(b"published fixture").hexdigest()}  {name}\n'
                       for name in ['Neutron.zip', 'Neutron-0.1.0-alpha.6.dmg', 'SOURCE.json'])
        (repo / 'release/SHA256SUMS').write_text(sums)
        ET.ElementTree(self.item('0.1.0-alpha.6', 402)).write(repo / 'release/item.xml')
        ET.ElementTree(metadata.merge_feed(self.item('0.1.0-alpha.5', 401))).write(repo / 'old.xml')
        bin_path = repo / 'bin'
        bin_path.mkdir()
        gh = bin_path / 'gh'
        gh.write_text('''#!/usr/bin/env python3
import json, os, pathlib, shutil, sys
args = sys.argv[1:]
with open('calls.jsonl', 'a') as log:
    log.write(json.dumps(args) + '\\n')
if args[:2] == ['release', 'view']:
    if args[2] == 'updates':
        print(json.dumps({'assets': [{'name': 'appcast.xml'}]}))
    elif os.environ.get('ALREADY_PUBLISHED'):
        print(json.dumps({'isDraft': False}))
    else:
        sys.exit(1)
elif args[:2] == ['release', 'download']:
    destination = pathlib.Path(args[args.index('--dir') + 1])
    if args[2] == 'updates':
        shutil.copy('old.xml', destination / 'appcast.xml')
    else:
        shutil.copy('release/SHA256SUMS', destination / 'SHA256SUMS')
        if os.environ.get('MISMATCH'):
            (destination / 'SHA256SUMS').write_text('different published bytes')
''')
        gh.chmod(0o755)
        # macOS calls this shasum; GitHub's Linux publisher calls it sha256sum.
        sha256sum = bin_path / 'sha256sum'
        sha256sum.write_text('#!/bin/sh\nexec shasum -a 256 "$@"\n')
        sha256sum.chmod(0o755)
        environment = dict(os.environ, PATH=str(bin_path) + os.pathsep + os.environ['PATH'],
                           GITHUB_REPOSITORY='flymedia-us/neutron', RELEASE_TAG='v0.1.0-alpha.6',
                           RELEASE_VERSION='0.1.0-alpha.6')
        def publish(**overrides):
            # A publish-job retry gets a fresh artifact checkout.
            for name in ['previous', 'published']:
                shutil.rmtree(repo / 'release' / name, ignore_errors=True)
            (repo / 'calls.jsonl').write_text('')
            result = subprocess.run(['bash', 'scripts/release-publish.sh'], cwd=repo,
                                    env=dict(environment, **overrides), capture_output=True, text=True)
            commands = [json.loads(line) for line in (repo / 'calls.jsonl').read_text().splitlines()]
            return result, commands
        result, commands = publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        edit = next(c for c in commands if c[:2] == ['release', 'edit'])
        self.assertIn('--latest', edit)
        self.assertIn('--prerelease=false', edit)
        self.assertEqual(edit[edit.index('--title') + 1], '0.1.0-alpha.6')
        self.assertIn('--notes-file', edit)
        self.assertEqual(commands[-1][:3], ['release', 'upload', 'updates'])
        feed = ET.parse(repo / 'release/appcast.xml')
        self.assertEqual(feed.findtext(f'./channel/item/{{{metadata.SPARKLE}}}channel'), 'preview')
        self.assertEqual(len(feed.findall('./channel/item')), 2)
        result, commands = publish(ALREADY_PUBLISHED='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([c[2] for c in commands if c[:2] == ['release', 'upload']], ['updates'])
        result, commands = publish(ALREADY_PUBLISHED='1', MISMATCH='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c[:2] in [['release', 'edit'], ['release', 'upload']] for c in commands))
        # A late retry must not demote the current Latest or roll back its feed.
        ET.ElementTree(metadata.merge_feed(self.item('0.1.0-alpha.7', 403))).write(repo / 'old.xml')
        result, commands = publish(ALREADY_PUBLISHED='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c[:2] in [['release', 'edit'], ['release', 'upload']] for c in commands))

    def test_main_automatically_tags_new_versions_without_duplicate_releases(self):
        repo = pathlib.Path(self.work.name) / 'automatic-source'
        repo.mkdir()
        def git(*args):
            return subprocess.check_output(['git', '-C', str(repo), *args], text=True).strip()
        git('init', '-q', '-b', 'main')
        git('config', 'user.name', 'Release fixture')
        git('config', 'user.email', 'release@example.invalid')
        (repo / 'scripts').mkdir()
        (repo / 'dylib').mkdir()
        for name in ['auto-release.sh', 'release-metadata.py']:
            shutil.copy(ROOT / name, repo / 'scripts' / name)
        version = repo / 'dylib/version.h'
        version.write_text('#define NOTPROTON_VERSION "0.1.0-alpha.5"\n')
        git('add', '.')
        git('commit', '-qm', 'Reviewed version')
        git('update-ref', 'refs/remotes/origin/main', 'HEAD')
        bin_path = pathlib.Path(self.work.name) / 'bin'
        bin_path.mkdir()
        calls = pathlib.Path(self.work.name) / 'gh-calls.jsonl'
        gh = bin_path / 'gh'
        gh.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['GH_CALLS'], 'a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1:3] == ['run', 'list']:
    print('[{"databaseId": 42}]' if os.environ.get('EXISTING_RELEASE') else '[]')
''')
        gh.chmod(0o755)
        def prepare(**overrides):
            calls.write_text('')
            environment = dict(os.environ, PATH=str(bin_path) + os.pathsep + os.environ['PATH'],
                               GH_CALLS=str(calls), GITHUB_REPOSITORY='flymedia-us/neutron',
                               GITHUB_REF='refs/heads/main', GITHUB_SHA=git('rev-parse', 'HEAD'))
            environment.update(overrides)
            result = subprocess.run(['bash', 'scripts/auto-release.sh'], cwd=repo,
                                    env=environment, capture_output=True, text=True)
            return result, [json.loads(line) for line in calls.read_text().splitlines()]
        result, commands = prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([c[:2] for c in commands], [['run', 'list'], ['api', '--method'], ['workflow', 'run']])
        self.assertIn('ref=refs/tags/v0.1.0-alpha.5', commands[1])
        self.assertEqual(commands[2][-2:], ['--ref', 'v0.1.0-alpha.5'])
        git('tag', 'v0.1.0-alpha.5')
        # Interrupted dispatch is recoverable without overwriting the existing tag.
        result, commands = prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([c[:2] for c in commands], [['run', 'list'], ['workflow', 'run']])
        result, commands = prepare(EXISTING_RELEASE='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(commands), 1)
        # Ordinary main updates do not republish a previously tagged version.
        (repo / 'readme.txt').write_text('Documentation update')
        git('add', '.')
        git('commit', '-qm', 'Same version')
        git('update-ref', 'refs/remotes/origin/main', 'HEAD')
        result, commands = prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [])
        version.write_text('#define NOTPROTON_VERSION "0.1.0-alpha.6"\n')
        git('add', '.')
        git('commit', '-qm', 'Next version')
        git('update-ref', 'refs/remotes/origin/main', 'HEAD')
        result, commands = prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('ref=refs/tags/v0.1.0-alpha.6', commands[1])
        result, commands = prepare(GITHUB_REF='refs/heads/unreviewed')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, [])
        (repo / 'dirty.txt').write_text('Uncommitted')
        result, commands = prepare()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, [])

    def test_release_preflight_reports_names_without_disclosing_credentials(self):
        self.assertEqual(len(configuration.errors({})), len(configuration.NAMES))
        values = {name: 'secret-do-not-print' for name in configuration.NAMES}
        values['DEVELOPER_ID_P12_BASE64'] = base64.b64encode(b'certificate fixture').decode()
        values['SPARKLE_PRIVATE_KEY'] = base64.b64encode(bytes(32)).decode()
        values['SPARKLE_PUBLIC_KEY'] = base64.b64encode(bytes(32)).decode()
        values['APP_STORE_CONNECT_API_KEY'] = '-----BEGIN PRIVATE KEY-----\nfixture\n-----END PRIVATE KEY-----'
        self.assertEqual(configuration.errors(values), [])
        values['SPARKLE_PRIVATE_KEY'] = 'secret-do-not-print'
        values['APP_STORE_CONNECT_API_KEY'] = base64.b64encode(b'private fixture').decode()
        problems = configuration.errors(values)
        self.assertEqual(len(problems), 2)
        self.assertNotIn('secret-do-not-print', '\n'.join(problems))

    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.archive = pathlib.Path(self.work.name) / 'Neutron.zip'
        self.archive.write_bytes(b'archive fixture')
        self.signature = base64.b64encode(bytes(64)).decode()

    def item(self, version, build):
        return metadata.release_item({'CFBundleShortVersionString': version,
                                      'CFBundleVersion': str(build)}, self.archive, self.signature)

    def test_release_validation_accepts_clean_main_and_rejects_dirty_or_unreviewed_sources(self):
        repo = pathlib.Path(self.work.name) / 'source'
        repo.mkdir()
        def git(*args):
            return subprocess.check_output(['git', '-C', str(repo), *args], text=True).strip()
        git('init', '-q', '-b', 'main')
        git('config', 'user.name', 'Release fixture')
        git('config', 'user.email', 'release@example.invalid')
        (repo / 'dylib').mkdir()
        (repo / 'dylib/version.h').write_text('#define NOTPROTON_VERSION "0.1.0-alpha.5"\n')
        git('add', '.')
        git('commit', '-qm', 'Reviewed source')
        git('update-ref', 'refs/remotes/origin/main', 'HEAD')
        command = ['python3', str(ROOT / 'release-metadata.py'), 'validate', 'v0.1.0-alpha.5']
        result = subprocess.run(command, cwd=repo, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"prerelease": true', result.stdout)
        wrong_tag = subprocess.run(command[:-1] + ['v0.1.0'], cwd=repo, capture_output=True)
        self.assertNotEqual(wrong_tag.returncode, 0)
        (repo / 'unreviewed.txt').write_text('local modification')
        self.assertNotEqual(subprocess.run(command, cwd=repo, capture_output=True).returncode, 0)
        git('add', '.')
        git('commit', '-qm', 'Not on reviewed main')
        self.assertNotEqual(subprocess.run(command, cwd=repo, capture_output=True).returncode, 0)

    def test_preview_does_not_remove_the_last_stable_update(self):
        feed = metadata.merge_feed(self.item('0.1.0', 400))
        for build in range(401, 430):
            feed = metadata.merge_feed(self.item(f'0.2.0-beta.{build}', build), feed)
        items = feed.findall('./channel/item')
        stable = [i for i in items if i.find(f'{{{metadata.SPARKLE}}}channel') is None]
        self.assertEqual([i.findtext(f'{{{metadata.SPARKLE}}}version') for i in stable], ['400'])
        self.assertEqual(len(items), 30)
        feed = metadata.merge_feed(self.item('0.2.0-beta.429', 429), feed)
        self.assertEqual(len(feed.findall('./channel/item')), 30)

    def test_update_urls_and_requirements_match_shipping_platform(self):
        item = self.item('0.1.0-alpha.5', 401)
        self.assertEqual(item.findtext(f'{{{metadata.SPARKLE}}}channel'), 'preview')
        enclosure = item.find('enclosure')
        self.assertEqual(enclosure.get('url'), 'https://github.com/flymedia-us/neutron/releases/download/v0.1.0-alpha.5/Neutron.zip')
        self.assertEqual(enclosure.get('length'), str(self.archive.stat().st_size))
        self.assertEqual(item.findtext(f'{{{metadata.SPARKLE}}}minimumSystemVersion'), '15.0.0')
        self.assertEqual(item.findtext(f'{{{metadata.SPARKLE}}}hardwareRequirements'), 'arm64')
        # XML must round-trip even with text requiring escaping.
        self.assertEqual(ET.fromstring(ET.tostring(item)).find('enclosure').get(f'{{{metadata.SPARKLE}}}edSignature'), self.signature)
        with self.assertRaises(ValueError):
            metadata.release_item({'CFBundleShortVersionString': '1.0.0'}, self.archive, 'invalid')

    def test_contributor_builds_disable_background_updates_and_remove_old_keys(self):
        path = pathlib.Path(self.work.name) / 'Info.plist'
        path.write_bytes(plistlib.dumps({'SUPublicEDKey': 'stale', 'SUEnableAutomaticChecks': True}))
        updater.configure(path, '')
        info = plistlib.loads(path.read_bytes())
        self.assertNotIn('SUPublicEDKey', info)
        self.assertFalse(info['SUEnableAutomaticChecks'])

    def test_release_key_is_public_and_validated_before_embedding(self):
        path = pathlib.Path(self.work.name) / 'Info.plist'
        path.write_bytes(plistlib.dumps({'SUEnableAutomaticChecks': False}))
        before = path.read_bytes()
        for invalid in ['not a key', base64.b64encode(bytes(64)).decode()]:
            with self.assertRaises(ValueError):
                updater.configure(path, invalid)
            self.assertEqual(path.read_bytes(), before)
        public = base64.b64encode(bytes(32)).decode()
        updater.configure(path, public)
        info = plistlib.loads(path.read_bytes())
        self.assertEqual(info['SUPublicEDKey'], public)
        self.assertTrue(info['SUEnableAutomaticChecks'])


if __name__ == '__main__':
    unittest.main()
