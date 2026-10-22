#!/usr/bin/env python3
"""Release regressions: channel history, update authentication, and local builds."""
import base64
import importlib.util
import pathlib
import plistlib
import subprocess
import tempfile
import unittest
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


class ReleaseTests(unittest.TestCase):
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
