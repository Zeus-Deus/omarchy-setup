from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
FEATURE = ROOT / 'features/herdr'

BASE = '''onboarding = false
# Omarchy default

[ui]
accent = "blue"
# keep this comment
pane_gaps = false

[ui.toast]
delivery = "system"
'''


class OverridesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.config = self.dir / 'config.toml'
        self.config.write_text(BASE)

    def apply(self, overrides):
        path = self.dir / 'overrides.toml'
        path.write_text(overrides)
        return subprocess.run(['/usr/bin/python3', str(FEATURE / 'apply-overrides.py'),
                               str(path), str(self.config)],
                              capture_output=True, text=True, timeout=10)

    def backups(self):
        return list(self.dir.glob('config.toml.bak.*'))

    def test_adds_key_to_existing_section_and_keeps_other_lines(self):
        result = self.apply('[ui]\nsidebar_max_width = 60\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        text = self.config.read_text()
        self.assertIn('sidebar_max_width = 60  # omarchy-setup', text)
        self.assertIn('# keep this comment', text)
        data = tomllib.loads(text)
        self.assertEqual(data['ui']['sidebar_max_width'], 60)
        self.assertEqual(data['ui']['accent'], 'blue')
        self.assertEqual(data['ui']['toast']['delivery'], 'system')
        self.assertEqual(len(self.backups()), 1)
        self.assertEqual(self.backups()[0].read_text(), BASE)

    def test_matching_config_is_not_touched(self):
        self.assertEqual(self.apply('[ui]\naccent = "blue"\n').stdout, '')
        self.assertEqual(self.config.read_text(), BASE)
        self.assertEqual(self.backups(), [])

    def test_idempotent(self):
        overrides = '[ui]\nsidebar_max_width = 60\n[ui.toast]\ndelivery = "app"\n'
        self.apply(overrides)
        once = self.config.read_text()
        result = self.apply(overrides)
        self.assertEqual(result.stdout, '')
        self.assertEqual(self.config.read_text(), once)

    def test_replaces_value_and_adds_missing_section(self):
        self.apply('[ui]\naccent = "red"\n[keys]\nprefix = "ctrl+a"\n')
        data = tomllib.loads(self.config.read_text())
        self.assertEqual(data['ui']['accent'], 'red')
        self.assertEqual(data['keys']['prefix'], 'ctrl+a')

    def test_invalid_overrides_change_nothing(self):
        for overrides in ('[ui\nbroken', '[[ui.list]]\na = 1\n'):
            self.assertNotEqual(self.apply(overrides).returncode, 0)
        self.assertEqual(self.config.read_text(), BASE)
        self.assertEqual(self.backups(), [])


if __name__ == '__main__':
    unittest.main()
