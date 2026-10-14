"""Run the real preinstall logic against disposable homes, never live installs."""
from pathlib import Path
import os
import plistlib
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'Scripts/Installer/preinstall'


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ArmKeyKey installer tests ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.users = self.root / 'Users'
        self.users.mkdir()
        self.home = self.users / 'Test User'
        self.methods = self.home / 'Library/Input Methods'
        self.methods.mkdir(parents=True)
        self.app = self.methods / 'ArmKeyKey.app'
        self.data = self.home / 'Library/Application Support/ArmKeyKey/learning.txt'
        self.data.parent.mkdir(parents=True)
        self.data.write_text('preserve my learning')

    def app_fixture(self, home=None):
        app = (home / 'Library/Input Methods/ArmKeyKey.app') if home else self.app
        app.mkdir(parents=True)
        (app / 'old-binary').write_text('old version')
        (app / 'Contents').mkdir()
        (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '0.9.1', 'CFBundleVersion': '18'}))
        return app

    def run_script(self, running=False, console_home=None, receipt=False):
        # Rewrite only OS integration boundaries in a temporary copy. The release
        # script accepts no environment variables that can bypass safety checks.
        source = SOURCE.read_text().replace('/Users/*', '"' + str(self.users) + '"/*')
        source = source.replace("'/Library/", "'" + str(self.root / 'Shared') + '/')
        (self.root / 'Shared').mkdir(exist_ok=True)
        source = source.replace('/usr/sbin/pkgutil --pkg-info everstar.armkeykey.mac.pkg', '/usr/bin/true' if receipt else '/usr/bin/false')
        source = source.replace('/usr/bin/pgrep -x ArmKeyKey', '/usr/bin/true' if running else '/usr/bin/false')
        source = source.replace('/usr/bin/stat -f %Su /dev/console', '/usr/bin/printf test' if console_home else '/usr/bin/printf root')
        if console_home:
            source = source.replace('/usr/bin/dscl . -read "/Users/$console_user" NFSHomeDirectory', '/usr/bin/printf "NFSHomeDirectory: ' + str(console_home) + '\\n"')
        script = self.root / 'preinstall'
        script.write_text(source)
        return subprocess.run(['/bin/bash', str(script)], capture_output=True, text=True)

    def run_postinstall(self):
        source = SOURCE.with_name('postinstall').read_text()
        source = source.replace("'/Library/", "'" + str(self.root / 'Shared') + '/')
        source = source.replace('/usr/sbin/chown root:wheel', '/usr/bin/true')
        script = self.root / 'postinstall'
        script.write_text(source)
        return subprocess.run(['/bin/bash', str(script)], capture_output=True, text=True)

    @property
    def agent(self):
        return self.root / 'Shared/LaunchAgents/everstar.armkeykey.first-login.plist'

    def test_fresh_install_schedules_next_login_only(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.assertFalse(self.agent.exists(), 'Do not schedule until payload installation succeeds')
        self.assertEqual(self.run_postinstall().returncode, 0)
        config = plistlib.loads(self.agent.read_bytes())
        self.assertTrue(config['RunAtLoad'])
        self.assertEqual(config['LimitLoadToSessionType'], 'Aqua')
        self.assertEqual(config['ProgramArguments'], ['/Library/Input Methods/ArmKeyKey.app/Contents/MacOS/ArmKeyKey', '--first-login-setup'])
        self.assertNotIn('KeepAlive', config)
        self.assertFalse((self.root / 'Shared/ArmKeyKey Setup/pending').exists())
        self.assertEqual(self.run_postinstall().returncode, 0)

    def test_shared_upgrade_does_not_schedule_guide(self):
        shared = self.root / 'Shared/Input Methods/ArmKeyKey.app'
        shared.mkdir(parents=True)
        (shared / 'Contents').mkdir()
        (shared / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '0.9.1', 'CFBundleVersion': '18'}))
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.run_postinstall().returncode, 0)
        self.assertFalse(self.agent.exists())

    def test_personal_migration_does_not_schedule_guide(self):
        self.app_fixture()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.run_postinstall().returncode, 0)
        self.assertFalse(self.agent.exists())

    def test_stale_receipt_does_not_suppress_fresh_setup(self):
        self.assertEqual(self.run_script(receipt=True).returncode, 0)
        self.assertEqual(self.run_postinstall().returncode, 0)
        self.assertTrue(self.agent.exists())

    def test_existing_install_clears_stale_pending(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.app_fixture()
        self.assertEqual(self.run_script(receipt=True).returncode, 0)
        self.assertEqual(self.run_postinstall().returncode, 0)
        self.assertFalse(self.agent.exists())

    def test_broken_build19_test_install_is_repaired(self):
        shared = self.root / 'Shared/Input Methods/ArmKeyKey.app/Contents'
        shared.mkdir(parents=True)
        (shared / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '0.9.2', 'CFBundleVersion': '19'}))
        self.assertEqual(self.run_script(receipt=True).returncode, 0)
        self.assertEqual(self.run_postinstall().returncode, 0)
        self.assertTrue(self.agent.exists())
        self.assertEqual((self.root / 'Shared/ArmKeyKey Setup/last-install').read_text().strip(), 'repair-build19-first-login')

    def test_empty_leftover_directory_still_gets_guide(self):
        self.app.mkdir()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.run_postinstall().returncode, 0)
        self.assertTrue(self.agent.exists())

    def test_upgrade_preserves_existing_fresh_install_agent(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.run_postinstall().returncode, 0)
        original = self.agent.read_bytes()
        shared = self.root / 'Shared/Input Methods/ArmKeyKey.app/Contents'
        shared.mkdir(parents=True)
        (shared / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '0.9.2', 'CFBundleVersion': '20'}))
        self.assertEqual(self.run_script(receipt=True).returncode, 0)
        self.assertEqual(self.run_postinstall().returncode, 0)
        self.assertEqual(self.agent.read_bytes(), original)

    def test_symlink_setup_and_agent_paths_are_rejected(self):
        shared = self.root / 'Shared'
        shared.mkdir()
        outside = self.root / 'outside'
        outside.mkdir()
        (shared / 'ArmKeyKey Setup').symlink_to(outside)
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])
        (shared / 'ArmKeyKey Setup').unlink()
        self.assertEqual(self.run_script().returncode, 0)
        (shared / 'LaunchAgents').symlink_to(outside)
        self.assertNotEqual(self.run_postinstall().returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])

    def test_clean_and_repeat_install(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.data.read_text(), 'preserve my learning')

    def test_personal_copy_is_backed_up_with_data_intact(self):
        self.app_fixture()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.app.exists())
        backups = list((self.home / 'Library').glob('ArmKeyKey Installer Backup.*/ArmKeyKey.app/old-binary'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'old version')
        self.assertEqual(self.data.read_text(), 'preserve my learning')
        self.assertEqual(self.run_script().returncode, 0)
        self.app_fixture()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(len(list((self.home / 'Library').glob('ArmKeyKey Installer Backup.*'))), 2)

    def test_running_app_does_not_block_upgrade(self):
        self.app_fixture()
        result = self.run_script(running=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.app.exists())
        self.assertEqual(self.data.read_text(), 'preserve my learning')

    def test_shared_bundle_stays_in_place_and_is_backed_up(self):
        shared = self.root / 'Shared/Input Methods/ArmKeyKey.app'
        shared.mkdir(parents=True)
        binary = shared / 'old-binary'
        binary.write_bytes(b'old running image')
        inode = binary.stat().st_ino
        with binary.open('rb') as mapped:
            result = self.run_script(running=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(binary.stat().st_ino, inode)
            self.assertEqual(mapped.read(), b'old running image')
        backups = list((self.root / 'Shared').glob('ArmKeyKey Installer Backup.*/ArmKeyKey.app/old-binary'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), binary.read_bytes())

    def test_shared_symlink_rejected_before_any_backup(self):
        shared = self.root / 'Shared/Input Methods'
        shared.mkdir(parents=True)
        (shared / 'ArmKeyKey.app').symlink_to(self.root / 'missing')
        self.app_fixture()
        self.assertNotEqual(self.run_script(running=True).returncode, 0)
        self.assertTrue(self.app.exists())

    def test_no_process_killing_or_running_process_gate(self):
        source = SOURCE.read_text()
        for forbidden in ['pgrep', 'pkill', 'killall', '/bin/kill']:
            self.assertNotIn(forbidden, source)
        builder = (SOURCE.parents[1] / 'build-pkg.py').read_text()
        self.assertIn("entry['BundleOverwriteAction'] = 'upgrade'", builder)
        self.assertIn('onConclusion="RequireLogout"', builder)

    def test_symlink_is_rejected_without_touching_target(self):
        target = self.root / 'outside'
        target.mkdir()
        self.app.symlink_to(target)
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertTrue(self.app.is_symlink())
        self.assertTrue(target.exists())

    def test_broken_symlink_is_rejected(self):
        self.app.symlink_to(self.root / 'missing')
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertTrue(self.app.is_symlink())

    def test_custom_console_home_and_duplicate_home(self):
        custom = self.root / 'Custom Home'
        app = self.app_fixture(custom)
        self.app_fixture()
        self.assertEqual(self.run_script(console_home=custom).returncode, 0)
        self.assertFalse(app.exists())
        self.assertFalse(self.app.exists())
        self.app_fixture()
        self.assertEqual(self.run_script(console_home=self.home).returncode, 0)

    def test_empty_leftover_app_directory(self):
        self.app.mkdir()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertFalse(self.app.exists())

    def test_invalid_second_home_does_not_move_first(self):
        self.app_fixture()
        other = self.users / 'Z Other/Library/Input Methods'
        other.mkdir(parents=True)
        (other / 'ArmKeyKey.app').symlink_to(self.root / 'missing')
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertTrue(self.app.exists())


if __name__ == '__main__':
    unittest.main()
