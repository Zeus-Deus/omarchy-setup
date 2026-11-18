from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'features/proton-games/proton-prefix.py'
APPID = '4242'
SINK = 'alsa_output.test_headset.stereo-game'
# Bytes 00..ff in registry order; the first three GUID fields are little-endian.
ENDPOINT = '{0.0.0.00000000}.{33221100-5544-7766-8899-AABBCCDDEEFF}'

REGISTRY = r'''WINE REGISTRY Version 2
;; All keys relative to REGISTRY\\User\\S-1-5-21-0-0-0-1000

#arch=win64

[Software\\Wine\\AppDefaults\\Game.exe\\DllOverrides] 1794497076
#time=1dd72b9ed0d2b06
"atiadlxx"="builtin"

[Software\\Wine\\Drivers\\winepulse.drv\\devices\\0,] 1795024839
#time=1dd7786b88406ee
"guid"=hex:ff,ee,dd,cc,bb,aa,99,88,77,66,55,44,33,22,11,00

[Software\\Wine\\Drivers\\winepulse.drv\\devices\\0,alsa_output.test_headset.stereo-game] 1795024839
#time=1dd7786b88445b4
"guid"=hex:00,11,22,33,44,55,66,77,88,99,aa,bb,cc,dd,ee,ff

[Software\\Wine\\Drivers\\winepulse.drv\\devices\\1,alsa_input.test_headset.mono-chat] 1795024839
#time=1dd7786b8853942
"guid"=hex:d6,98,f4,7a,14,68,6f,46,b6,72,89,11,c2,a0,50,99
'''


class ProtonPrefixTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        self.steam = base / 'steam'
        library = base / 'library'
        self.prefix = library / 'steamapps/compatdata' / APPID / 'pfx'
        self.prefix.mkdir(parents=True)
        (self.steam / 'steamapps').mkdir(parents=True)
        (self.steam / 'steamapps/libraryfolders.vdf').write_text(
            f'"libraryfolders"\n{{\n\t"0"\n\t{{\n\t\t"path"\t\t"{library}"\n\t}}\n}}\n')
        self.registry = self.prefix / 'user.reg'
        self.registry.write_text(REGISTRY)
        self.state = base / 'state'
        self.proc = base / 'proc'
        self.proc.mkdir()

    def run_tool(self, *args):
        return subprocess.run(
            [sys.executable, str(TOOL), *args, '--steam-root', str(self.steam),
             '--state-dir', str(self.state), '--proc', str(self.proc)],
            capture_output=True, text=True)

    def backups(self):
        return sorted(self.state.rglob('user.reg')) if self.state.exists() else []

    def test_output_is_written_as_uppercase_endpoint_and_backed_up(self):
        result = self.run_tool('set', APPID, '--output', SINK)
        self.assertEqual(result.returncode, 0, result.stderr)
        text = self.registry.read_text()
        self.assertIn('[Software\\\\Wine\\\\Drivers\\\\winepulse.drv] ', text)
        self.assertIn(f'"DefaultOutput"="{ENDPOINT}"', text)
        self.assertTrue(text.startswith(REGISTRY))
        self.assertEqual([path.read_text() for path in self.backups()], [REGISTRY])

    def test_repeat_is_unchanged_and_makes_no_second_backup(self):
        self.run_tool('set', APPID, '--output', SINK, '--exe', 'Game.exe', '--grab-pointer', 'off')
        first = self.registry.read_bytes()
        result = self.run_tool('set', APPID, '--output', SINK, '--exe', 'Game.exe',
                               '--grab-pointer', 'off')
        self.assertIn('unchanged', result.stdout)
        self.assertEqual(self.registry.read_bytes(), first)
        self.assertEqual(len(self.backups()), 1)

    def test_grab_pointer_off_then_on_restores_wine_default(self):
        self.run_tool('set', APPID, '--exe', 'Game.exe', '--grab-pointer', 'off')
        text = self.registry.read_text()
        self.assertIn('[Software\\\\Wine\\\\AppDefaults\\\\Game.exe\\\\X11 Driver] ', text)
        self.assertIn('"GrabPointer"="N"', text)
        self.assertIn('"atiadlxx"="builtin"', text)
        self.run_tool('set', APPID, '--exe', 'Game.exe', '--grab-pointer', 'on')
        self.assertNotIn('GrabPointer', self.registry.read_text())

    def test_output_default_removes_the_override(self):
        self.run_tool('set', APPID, '--output', SINK)
        self.run_tool('set', APPID, '--output', 'default')
        self.assertNotIn('DefaultOutput', self.registry.read_text())

    def test_unknown_output_fails_without_touching_the_registry(self):
        result = self.run_tool('set', APPID, '--output', 'alsa_output.missing')
        self.assertEqual(result.returncode, 1)
        self.assertIn(SINK, result.stderr)
        self.assertEqual(self.registry.read_text(), REGISTRY)
        self.assertEqual(self.backups(), [])

    def test_running_game_blocks_the_write(self):
        process = self.proc / '123'
        process.mkdir()
        (process / 'environ').write_bytes(
            b'HOME=/x\0WINEPREFIX=' + str(self.prefix).encode() + b'\0')
        result = self.run_tool('set', APPID, '--output', SINK)
        self.assertEqual(result.returncode, 1)
        self.assertIn('still running', result.stderr)
        self.assertEqual(self.registry.read_text(), REGISTRY)

    def test_dry_run_writes_nothing(self):
        result = self.run_tool('set', APPID, '--output', SINK, '--dry-run')
        self.assertIn('would change', result.stdout)
        self.assertEqual(self.registry.read_text(), REGISTRY)
        self.assertEqual(self.backups(), [])

    def test_missing_prefix_is_an_error_for_set(self):
        result = self.run_tool('set', '999', '--output', SINK)
        self.assertEqual(result.returncode, 1)
        self.assertIn('launch the game once', result.stderr)

    def test_apply_reports_each_game(self):
        games = Path(self.tmp.name) / 'games.toml'
        games.write_text(
            f'[[game]]\nappid = {APPID}\nname = "Test Game"\nexe = "Game.exe"\n'
            f'grab_pointer = false\noutput = "{SINK}"\n\n'
            '[[game]]\nappid = 999\nname = "Not Installed"\noutput = "default"\n')
        result = self.run_tool('apply', str(games))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f'{APPID} Test Game: changed', result.stdout)
        self.assertIn('999 Not Installed: skipped', result.stdout)
        text = self.registry.read_text()
        self.assertIn(f'"DefaultOutput"="{ENDPOINT}"', text)
        self.assertIn('"GrabPointer"="N"', text)
        self.assertEqual(len(self.backups()), 1)

    def test_apply_fails_loudly_on_a_bad_entry(self):
        games = Path(self.tmp.name) / 'games.toml'
        games.write_text(f'[[game]]\nappid = {APPID}\noutputs = "typo"\n')
        result = self.run_tool('apply', str(games))
        self.assertEqual(result.returncode, 1)
        self.assertIn('FAILED', result.stderr)
        self.assertEqual(self.registry.read_text(), REGISTRY)

    def test_show_names_the_selected_output(self):
        self.run_tool('set', APPID, '--output', SINK, '--exe', 'Game.exe', '--grab-pointer', 'off')
        result = self.run_tool('show', APPID)
        self.assertIn(f'output: {SINK}', result.stdout)
        self.assertIn('Game.exe=N', result.stdout)


if __name__ == '__main__':
    unittest.main()
