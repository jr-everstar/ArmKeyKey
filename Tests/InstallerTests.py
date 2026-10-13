"""Run the real preinstall logic against disposable homes, never live installs."""
from pathlib import Path
import os
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
        return app

    def run_script(self, running=False, console_home=None):
        # Rewrite only OS integration boundaries in a temporary copy. The release
        # script accepts no environment variables that can bypass safety checks.
        source = SOURCE.read_text().replace('/Users/*', '"' + str(self.users) + '"/*')
        source = source.replace("'/Library/Input Methods", "'" + str(self.root / 'Shared/Input Methods'))
        source = source.replace('/usr/bin/pgrep -x ArmKeyKey', '/usr/bin/true' if running else '/usr/bin/false')
        source = source.replace('/usr/bin/stat -f %Su /dev/console', '/usr/bin/printf test' if console_home else '/usr/bin/printf root')
        if console_home:
            source = source.replace('/usr/bin/dscl . -read "/Users/$console_user" NFSHomeDirectory', '/usr/bin/printf "NFSHomeDirectory: ' + str(console_home) + '\\n"')
        script = self.root / 'preinstall'
        script.write_text(source)
        return subprocess.run(['/bin/bash', str(script)], capture_output=True, text=True)

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

    def test_running_app_blocks_before_moving(self):
        self.app_fixture()
        self.assertNotEqual(self.run_script(running=True).returncode, 0)
        self.assertTrue(self.app.exists())

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
