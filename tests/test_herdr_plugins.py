import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
FEATURE = ROOT / 'features/herdr'


class PluginInstallTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.registry = self.home / 'registry.json'
        self.registry.write_text('[]')
        self.log = self.home / 'calls.jsonl'
        # The external CLI is simulated; the real restorer runs as a process.
        cli = self.bin / 'herdr'
        cli.write_text(r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
home = Path(os.environ['HOME'])
p = home / 'registry.json'
plugins = json.loads(p.read_text())
a = sys.argv[1:]
if a == ['--version']:
    print('herdr 0.9.1')
elif a == ['plugin', 'list', '--json']:
    print(json.dumps({'result': {'plugins': plugins, 'type': 'plugin_list'}}))
else:
    with (home / 'calls.jsonl').open('a') as log:
        log.write(json.dumps(a) + '\n')
    if a[:2] == ['plugin', 'install']:
        owner, repo = a[2].split('/')
        plugin_id = repo.removeprefix('herdr-')
        plugins = [x for x in plugins if x['plugin_id'] != plugin_id]
        ref = a[a.index('--ref') + 1]
        if os.environ.get('WRONG_REF'):
            ref = '0' * 40
        plugins.append({'plugin_id': plugin_id, 'enabled': True,
                        'source': {'kind': 'github', 'owner': owner, 'repo': repo,
                                   'resolved_commit': ref}})
    elif a[:2] in (['plugin', 'enable'], ['plugin', 'disable']):
        for item in plugins:
            if item['plugin_id'] == a[2]:
                item['enabled'] = a[1] == 'enable'
    else:
        sys.exit(2)
    p.write_text(json.dumps(plugins))
''')
        cli.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), PATH=f'{self.bin}:{os.environ["PATH"]}')
        self.pins = self.home / 'plugins.toml'
        self.pins.write_text('''min_herdr_version = "0.9.1"
[[plugins]]
id = "focus"
source = "Zeus-Deus/herdr-focus"
ref = "6c41b77130f3365f091a45cce102d56d07ac0359"
enabled = true
[[plugins]]
id = "peek"
source = "Zeus-Deus/herdr-peek"
ref = "3d3d8d2abe9517900e82131dc0407ca9fc4808d3"
enabled = true
''')
        self.heads = self.home / 'heads.json'
        self.heads.write_text(json.dumps({'herdr-focus': 'a' * 40, 'herdr-peek': 'b' * 40}))
        git = self.bin / 'git'
        git.write_text(r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
home = Path(os.environ['HOME'])
a = sys.argv[1:]
with (home / 'git-calls.jsonl').open('a') as log:
    log.write(json.dumps(a) + '\n')
if len(a) != 4 or a[:2] != ['ls-remote', '--exit-code'] or a[3] != 'HEAD':
    sys.exit(2)
repo = a[2].rsplit('/', 1)[-1].removesuffix('.git')
if os.environ.get('FAIL_LATEST_REPO') == repo:
    sys.exit(2)
value = json.loads((home / 'heads.json').read_text())[repo]
print(value + '\tHEAD')
''')
        git.chmod(0o755)

    def run_installer(self, **extra):
        return subprocess.run(['python3', str(FEATURE / 'install-plugins.py'),
                               str(self.pins)],
                              env=dict(self.env, **extra), capture_output=True, text=True, timeout=10)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_rejects_an_install_that_resolved_the_wrong_commit(self):
        result = self.run_installer(WRONG_REF='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Could not verify installed revision', result.stderr)
        self.assertEqual(len(self.calls()), 1)

    def test_refuses_to_replace_a_linked_plugin_before_installing_anything(self):
        self.registry.write_text(json.dumps([{'plugin_id': 'peek', 'enabled': True,
                                             'source': {'kind': 'local'}}]))
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('different or linked source', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_restores_enabled_state_without_reinstalling(self):
        self.assertEqual(self.run_installer().returncode, 0)
        plugins = json.loads(self.registry.read_text())
        plugins[0]['enabled'] = False
        self.registry.write_text(json.dumps(plugins))
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1], ['plugin', 'enable', 'focus'])
        self.assertEqual(len(self.calls()), 3)

    def test_installs_both_exact_pins_and_skips_a_second_install(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = [
            ['plugin', 'install', 'Zeus-Deus/herdr-focus', '--ref',
             '6c41b77130f3365f091a45cce102d56d07ac0359', '--yes'],
            ['plugin', 'install', 'Zeus-Deus/herdr-peek', '--ref',
             '3d3d8d2abe9517900e82131dc0407ca9fc4808d3', '--yes'],
        ]
        self.assertEqual(self.calls(), expected)
        self.assertEqual(self.run_installer().returncode, 0)
        self.assertEqual(self.calls(), expected)
        self.assertTrue(all(p['enabled'] for p in json.loads(self.registry.read_text())))

    def use_latest(self):
        self.pins.write_text(self.pins.read_text().replace(
            '6c41b77130f3365f091a45cce102d56d07ac0359', 'HEAD').replace(
            '3d3d8d2abe9517900e82131dc0407ca9fc4808d3', 'HEAD'))

    def test_latest_heads_are_refreshed_each_run_and_matching_commits_are_skipped(self):
        self.use_latest()
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = [
            ['plugin', 'install', 'Zeus-Deus/herdr-focus', '--ref', 'a' * 40, '--yes'],
            ['plugin', 'install', 'Zeus-Deus/herdr-peek', '--ref', 'b' * 40, '--yes'],
        ]
        self.assertEqual(self.calls(), expected)
        self.assertEqual(self.run_installer().returncode, 0)
        self.assertEqual(self.calls(), expected)
        lookups = [json.loads(line) for line in (self.home / 'git-calls.jsonl').read_text().splitlines()]
        self.assertEqual(len(lookups), 4)
        self.heads.write_text(json.dumps({'herdr-focus': 'c' * 40, 'herdr-peek': 'b' * 40}))
        self.assertEqual(self.run_installer().returncode, 0)
        self.assertEqual(self.calls(), expected + [
            ['plugin', 'install', 'Zeus-Deus/herdr-focus', '--ref', 'c' * 40, '--yes']])

    def test_repository_configuration_tracks_latest_default_branches(self):
        plugins = tomllib.loads((FEATURE / 'plugins.toml').read_text())['plugins']
        self.assertEqual({p['id'] for p in plugins}, {'focus', 'peek'})
        self.assertTrue(all(p['ref'] == 'HEAD' for p in plugins))

    def test_latest_lookup_failure_refuses_all_installs(self):
        self.use_latest()
        result = self.run_installer(FAIL_LATEST_REPO='herdr-peek')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertEqual(json.loads(self.registry.read_text()), [])

    def test_malformed_latest_commit_is_refused_before_install(self):
        self.use_latest()
        for value in ['abc', 'A' * 40, 'a' * 41, 'a' * 40 + '\tHEAD\n' + 'b' * 40]:
            with self.subTest(value=value):
                self.heads.write_text(json.dumps({'herdr-focus': value, 'herdr-peek': 'b' * 40}))
                result = self.run_installer()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Could not resolve latest commit', result.stderr)
                self.assertEqual(self.calls(), [])

    def test_latest_install_still_requires_exact_resolved_commit(self):
        self.use_latest()
        result = self.run_installer(WRONG_REF='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Could not verify installed revision', result.stderr)
        self.assertEqual(len(self.calls()), 1)

    def test_latest_enabled_state_restored_without_reinstall(self):
        self.use_latest()
        self.assertEqual(self.run_installer().returncode, 0)
        plugins = json.loads(self.registry.read_text())
        plugins[0]['enabled'] = False
        self.registry.write_text(json.dumps(plugins))
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1], ['plugin', 'enable', 'focus'])
        self.assertEqual(len(self.calls()), 3)


if __name__ == '__main__':
    unittest.main()
