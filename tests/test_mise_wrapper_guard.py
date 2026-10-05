import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FEATURE = ROOT / 'features/mise-wrapper-resolution'


def stock(package='codex', binary='codex'):
    # Explicit stock four-line fixture, not an installed Omarchy dependency.
    return ('#!/bin/bash\nexport MISE_MINIMUM_RELEASE_AGE=0\n'
            f'mise use -g --quiet "{package}" || exit 1\n'
            f'exec mise x "{package}" -- "{binary}" "$@"\n')


class GuardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / '.local/bin'
        self.bin.mkdir(parents=True)
        self.tools = self.home / 'tools'
        self.tools.mkdir()
        self.env = {'HOME': str(self.home), 'PATH': f'{self.tools}:/usr/bin:/bin',
                    'XDG_CONFIG_HOME': str(self.home / '.config'),
                    'XDG_DATA_HOME': str(self.home / 'data'),
                    'XDG_STATE_HOME': str(self.home / 'state'),
                    'XDG_CACHE_HOME': str(self.home / 'cache'),
                    'XDG_RUNTIME_DIR': str(self.home / 'run'),
                    # Never read the installed Omarchy package from a test.
                    'OMARCHY_PATH': str(self.home / 'omarchy')}
        # Only the supported hook installer is stubbed; reject any other call.
        self.write(self.tools / 'omarchy', '''#!/bin/bash
set -eu
[[ $# == 4 && $1 == hook && $2 == install && $3 == post-update ]] || exit 80
printf '%s\\n' "$*" >> "$HOME/omarchy.log"
dir="$HOME/.config/omarchy/hooks/post-update.d"
mkdir -p "$dir"
install -m 755 "$4" "$dir/$(basename "$4")"
''')

    def write(self, path, text):
        path.write_text(text)
        path.chmod(0o755)
        return path

    def install(self):
        return subprocess.run(['bash', str(FEATURE / 'install.sh')],
                              env=self.env, capture_output=True, text=True, timeout=15)

    def apply(self, *args):
        return subprocess.run(['/usr/bin/python3', str(FEATURE / 'guard.py'), *args],
                              env=self.env, capture_output=True, text=True, timeout=15)

    def test_legacy_migration_and_idempotence(self):
        legacy = FEATURE / 'fixtures/legacy-omarchy-mise-install.txt'
        self.assertFalse(os.access(legacy, os.X_OK))
        override = self.write(self.bin / 'omarchy-mise-install', legacy.read_text())
        original = override.read_bytes()
        wrapper = self.write(self.bin / 'codex', stock())
        for _ in range(2):
            result = self.install()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(override.exists(), 'known override must leave PATH')
        backups = list((self.home / 'state/mise-wrapper-guard/backups').rglob('omarchy-mise-install'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), original)
        self.assertEqual(len(list((self.home / 'state/mise-wrapper-guard/backups').rglob('codex'))), 1)
        self.assertIn('mise bin-paths', wrapper.read_text())

    def test_unknown_override_refused_and_preserved(self):
        override = self.write(self.bin / 'omarchy-mise-install', '#!/bin/bash\n# user customization\nexit 0\n')
        original = override.read_bytes()
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('WARNING', result.stderr)
        self.assertIn('unknown', result.stderr.lower())
        self.assertEqual(override.read_bytes(), original)
        self.assertFalse((self.home / 'omarchy.log').exists())

    def test_symlink_override_refused_even_if_target_matches(self):
        target = self.write(self.home / 'custom-generator',
                            (FEATURE / 'fixtures/legacy-omarchy-mise-install.txt').read_text())
        override = self.bin / 'omarchy-mise-install'
        override.symlink_to(target)
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(override.is_symlink())
        self.assertEqual(target.read_bytes(), (FEATURE / 'fixtures/legacy-omarchy-mise-install.txt').read_bytes())

    def test_non_utf8_wrapper_is_not_rewritten(self):
        wrapper = self.bin / 'invalid'
        raw = stock('http:bad\ufffd', 'invalid').encode().replace(b'\xef\xbf\xbd', b'\xff')
        wrapper.write_bytes(raw)
        wrapper.chmod(0o755)
        result = self.apply('--apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(wrapper.read_bytes(), raw)
        self.assertIn('WARNING invalid', result.stdout)

    def test_audit_and_existing_guard_preservation(self):
        wrapper = self.write(self.bin / 'codex', stock())
        result = self.apply()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('WOULD PROTECT codex', result.stdout)
        self.assertEqual(wrapper.read_text(), stock())
        self.assertFalse((self.home / 'state/mise-wrapper-guard/backups').exists())
        self.assertEqual(self.apply('--apply').returncode, 0)
        protected = wrapper.read_bytes()
        self.assertEqual(self.apply('--apply').returncode, 0)
        self.assertEqual(wrapper.read_bytes(), protected)

    def test_hook_failure_warns_without_blocking_update(self):
        # Missing helper deliberately exercises the real hook failure path.
        # An explicit nonexistent bus prevents reaching the live desktop.
        env = {**self.env, 'DBUS_SESSION_BUS_ADDRESS': f'unix:path={self.home}/no-bus'}
        result = subprocess.run(['bash', str(FEATURE / '50-mise-wrapper-guard')],
                                env=env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Protection check failed or timed out', result.stderr)

    def test_retires_once_upstream_generator_resolves_binaries(self):
        generator = self.home / 'omarchy/bin/omarchy-mise-install'
        generator.parent.mkdir(parents=True)
        self.write(generator, '#!/bin/bash\nbin_paths=$(mise bin-paths "$1")\n')
        wrapper = self.write(self.bin / 'codex', stock())
        result = self.apply('--apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(wrapper.read_text(), stock())
        self.assertIn('upstream fix detected', result.stdout)
        self.assertFalse((self.home / 'state/mise-wrapper-guard/backups').exists())

    def test_upstream_generated_wrapper_is_not_flagged(self):
        upstream = ('#!/bin/bash\nexport MISE_MINIMUM_RELEASE_AGE=0\n'
                    'mise use -g --quiet "codex" || exit 1\n'
                    'bin_paths=$(mise bin-paths "codex") || exit 1\n'
                    'exec mise x "codex" -- "$bin_path" "$@"\n')
        wrapper = self.write(self.bin / 'codex', upstream)
        result = self.apply('--apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(wrapper.read_text(), upstream)
        self.assertIn('PRESERVED codex', result.stdout)
        self.assertNotIn('WARNING', result.stdout)

    def test_fresh_setup(self):
        wrapper = self.write(self.bin / 'codex', stock())
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.bin / 'omarchy-mise-install').exists(),
                         'must not shadow the packaged generator')
        self.assertIn('mise bin-paths', wrapper.read_text())
        self.assertTrue((self.home / '.local/share/mise-wrapper-guard/guard.py').is_file())
        hook = self.home / '.config/omarchy/hooks/post-update.d/50-mise-wrapper-guard'
        self.assertEqual(hook.read_bytes(), (FEATURE / hook.name).read_bytes())
        self.assertIn('hook install post-update', (self.home / 'omarchy.log').read_text())
        # Simulate a later update regenerating the stock wrapper.
        wrapper.write_text(stock())
        result = subprocess.run(['bash', str(hook)], env=self.env,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('mise bin-paths', wrapper.read_text())


if __name__ == '__main__':
    unittest.main()
