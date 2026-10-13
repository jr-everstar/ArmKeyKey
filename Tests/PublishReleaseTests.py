"""Offline tests: no network, signing operations or release creation."""
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('publisher', Path(__file__).resolve().parents[1] / 'Scripts/publish-release.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class PublisherTests(unittest.TestCase):
    def test_incomplete_gates_block_before_network_or_build(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'Documentation').mkdir()
            (root / 'Documentation/release-readiness.json').write_text('{}')
            notes = root / 'notes.txt'; notes.write_text('test')
            with patch.object(p, 'ROOT', root), patch.object(p, 'gh') as remote, \
                    patch.object(p, 'build_package') as build, \
                    patch('sys.argv', ['publish', '--build', '--notes-file', str(notes), '--publish']), \
                    patch('sys.stdout', new_callable=io.StringIO):
                with self.assertRaises(ValueError):
                    p.main()
                remote.assert_not_called()
                build.assert_not_called()

    def test_build_preview_has_no_network_or_build(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'Documentation').mkdir()
            (root / 'Documentation/release-readiness.json').write_text('{}')
            notes = root / 'notes.txt'; notes.write_text('test')
            with patch.object(p, 'ROOT', root), patch.object(p, 'gh') as remote, \
                    patch.object(p, 'build_package') as build, \
                    patch('sys.argv', ['publish', '--build', '--notes-file', str(notes)]), \
                    patch('sys.stdout', new_callable=io.StringIO):
                p.main()
                remote.assert_not_called()
                build.assert_not_called()

    def test_direct_feed_pushes_main_without_pr(self):
        with tempfile.TemporaryDirectory() as folder:
            temporary=Path(folder)
            feed=temporary/'feed-repository/site/updates/stable.json'
            feed.parent.mkdir(parents=True)
            feed.write_text(json.dumps(self.feed()))
            with patch.object(p, 'gh', return_value='{"id": 1, "login": "maintainer"}') as remote, patch.object(p, 'run') as run:
                p.feed_direct(self.entry(), temporary)
                run.assert_any_call('git', 'push', 'origin', 'HEAD:main', cwd=temporary/'feed-repository')
                self.assertFalse(any(c.args[:1]==('pr',) for c in remote.call_args_list))
                self.assertFalse(any('--force' in c.args for c in run.call_args_list))
                run.reset_mock()
                p.feed_direct(self.entry(), temporary)
                run.assert_not_called()

    def feed(self):
        return {'schemaVersion': 1, 'bundleIdentifier': p.BUNDLE, 'channel': 'stable', 'releases': []}

    def entry(self, build=15):
        return {'version': '0.8.0', 'build': build, 'minimumSystemVersion': '26.0',
                'architectures': ['arm64'], 'notes': 'Test only', 'package': {
                    'url': f'https://github.com/{p.REPO}/releases/download/v0.8.0-build15/test.pkg',
                    'size': 3, 'sha256': '0' * 64}}

    def test_feed_preserves_history_and_is_idempotent(self):
        feed = p.add_release(self.feed(), self.entry(14))
        feed = p.add_release(feed, self.entry())
        self.assertEqual([r['build'] for r in feed['releases']], [15, 14])
        self.assertEqual(p.add_release(copy.deepcopy(feed), self.entry()), feed)

    def test_feed_rejects_conflicts_and_downgrades(self):
        feed = p.add_release(self.feed(), self.entry())
        with self.assertRaises(ValueError):
            p.add_release(copy.deepcopy(feed), self.entry(14))
        changed = self.entry(); changed['package']['sha256'] = '1' * 64
        with self.assertRaises(ValueError):
            p.add_release(copy.deepcopy(feed), changed)

    def asset_run(self, existing=None, download=b'pkg', public=b'pkg'):
        calls = []
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); pkg = root / 'test.pkg'; pkg.write_bytes(b'pkg')
            notes = root / 'notes.txt'; notes.write_text('test')
            def fake_gh(*args):
                calls.append(args)
                if args[:3] == ('api', '--paginate', '--slurp'):
                    return json.dumps([[existing]] if existing else [[]])
                if args[:2] == ('release', 'download'):
                    (Path(args[-1]) / 'test.pkg').write_bytes(download)
                return ''
            with patch.object(p, 'gh', side_effect=fake_gh), patch.object(p, 'run', return_value=''), \
                    patch.object(p.urllib.request, 'urlopen', return_value=io.BytesIO(public)):
                try:
                    p.ensure_asset('v0.8.0-build15', 'abc', pkg, notes, root)
                except ValueError:
                    return calls, False
        return calls, True

    def test_draft_verified_before_publish(self):
        calls, success = self.asset_run()
        self.assertTrue(success)
        actions = [c[1] for c in calls if c[0] == 'release']
        self.assertEqual(actions, ['create', 'upload', 'download', 'edit'])
        self.assertNotIn('--clobber', sum((list(c) for c in calls), []))

    def test_mismatch_never_publishes(self):
        calls, success = self.asset_run(download=b'wrong')
        self.assertFalse(success)
        self.assertFalse(any(c[:2] == ('release', 'edit') for c in calls))

    def test_existing_asset_is_not_overwritten(self):
        release = {'tag_name': 'v0.8.0-build15', 'draft': True, 'prerelease': False,
                   'target_commitish': 'abc', 'assets': [{'name': 'test.pkg'}]}
        calls, success = self.asset_run(existing=release, download=b'wrong')
        self.assertFalse(success)
        self.assertFalse(any(c[:2] == ('release', 'upload') for c in calls))

    def test_public_download_failure_stops_before_feed(self):
        _, success = self.asset_run(public=b'wrong')
        self.assertFalse(success)

    def test_existing_published_release_is_not_modified(self):
        release = {'tag_name': 'v0.8.0-build15', 'draft': False, 'prerelease': False, 'assets': []}
        calls, success = self.asset_run(existing=release)
        self.assertFalse(success)
        self.assertFalse(any(c[0] == 'release' for c in calls))


if __name__ == '__main__':
    unittest.main()
