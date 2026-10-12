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

    def test_replaces_multiline_sidebar_rows_without_losing_other_settings(self):
        self.config.write_text(BASE + '\n[ui.sidebar.agents]\nrows = [\n  ["workspace"],\n]\nrow_gap = 2\n')
        result = self.apply('[ui.sidebar.agents]\nrows = [\n  ["state_icon", "$ft"],\n]\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        data = tomllib.loads(self.config.read_text())
        self.assertEqual(data['ui']['sidebar']['agents']['rows'], [['state_icon', '$ft']])
        self.assertEqual(data['ui']['sidebar']['agents']['row_gap'], 2)
        self.assertIn('# keep this comment', self.config.read_text())
        once = self.config.read_bytes()
        self.assertEqual(self.apply('[ui.sidebar.agents]\nrows = [["state_icon", "$ft"]]\n').stdout, '')
        self.assertEqual(self.config.read_bytes(), once)

    def test_adding_a_key_after_multiline_rows_keeps_the_array_intact(self):
        self.config.write_text(BASE + '\n[ui.sidebar.agents]\nrows = [\n ["workspace"],\n]\n')
        result = self.apply('[ui.sidebar.agents]\nrow_gap = 0\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        sidebar = tomllib.loads(self.config.read_text())['ui']['sidebar']['agents']
        self.assertEqual(sidebar, {'rows': [['workspace']], 'row_gap': 0})

    def test_plugin_keys_merge_without_duplicate_or_removing_unrelated_keys(self):
        self.config.write_text(BASE + '\n[[keys.command]]\nkey = "prefix+b"\ntype = "shell"\ncommand = "date"\n# custom binding stays\n')
        overrides = '''[ui]
sidebar_max_width = 60
[[keys.command]]
key = "prefix+f"
type = "plugin_action"
command = "peek.pick"
description = "peek"
'''
        result = self.apply(overrides)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = tomllib.loads(self.config.read_text())
        self.assertEqual(len(data['keys']['command']), 2)
        self.assertEqual(data['keys']['command'][0]['command'], 'date')
        self.assertEqual(data['keys']['command'][1]['command'], 'peek.pick')
        self.assertIn('# custom binding stays', self.config.read_text())
        once = self.config.read_bytes()
        result = self.apply(overrides)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '')
        self.assertEqual(self.config.read_bytes(), once)

    def test_conflicting_shortcut_leaves_all_settings_and_backups_unchanged(self):
        self.config.write_text(BASE + '\n[[keys.command]]\nkey = "prefix+f"\ntype = "shell"\ncommand = "date"\n')
        before = self.config.read_bytes()
        result = self.apply('[ui]\naccent = "red"\n[[keys.command]]\nkey = "prefix+f"\ntype = "plugin_action"\ncommand = "peek.pick"\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('already assigned', result.stderr)
        self.assertEqual(self.config.read_bytes(), before)
        self.assertEqual(self.backups(), [])

    def test_existing_plugin_binding_is_updated_in_place(self):
        self.config.write_text(BASE + '\n[[keys.command]]\n# keep action comment\nkey = "prefix+g"\ntype = "plugin_action"\ncommand = "peek.pick"\n')
        result = self.apply('[[keys.command]]\nkey = "prefix+f"\ntype = "plugin_action"\ncommand = "peek.pick"\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        keys = tomllib.loads(self.config.read_text())['keys']['command']
        self.assertEqual(len(keys), 1)
        self.assertEqual(keys[0]['key'], 'prefix+f')
        self.assertIn('# keep action comment', self.config.read_text())

    def test_backup_preserves_private_permissions(self):
        self.config.chmod(0o600)
        result = self.apply('[ui]\nsidebar_max_width = 60\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.backups()[0].stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)

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
