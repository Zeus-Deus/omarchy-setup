import os, pathlib, subprocess, tempfile, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1] / 'features/mise-wrapper-resolution'
from test_mise_wrapper_guard import stock

def make_stock(home, package, binary):
    p = home/'.local/bin'/binary
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(stock(package, binary))
    p.chmod(0o755)
class GuardTest(unittest.TestCase):
    def test_stock_muse_protected_and_idempotent(self):
        with tempfile.TemporaryDirectory() as d:
            home = pathlib.Path(d)
            env = {'PATH':'/usr/bin:/bin', 'HOME':d, 'XDG_STATE_HOME':d+'/state', 'XDG_CONFIG_HOME':d+'/config', 'XDG_DATA_HOME':d+'/data', 'XDG_CACHE_HOME':d+'/cache', 'XDG_RUNTIME_DIR':d+'/run', 'OMARCHY_PATH':d+'/omarchy'}
            package='http:muse[url=https://example.com/launcher.sh,bin=muse]'
            make_stock(home, package, 'muse')
            p=home/'.local/bin/muse'
            original=p.read_bytes()
            self.assertTrue((ROOT/'guard.py').exists(), 'protection script must exist')
            for _ in range(2):
                subprocess.run(['/usr/bin/python3',str(ROOT/'guard.py'),'--apply'],env=env,check=True)
                text=p.read_text()
                self.assertIn('mise bin-paths',text)
                self.assertIn('flock',text)
                self.assertIn(package,text)
                subprocess.run(['/bin/bash','-n',str(p)],check=True)
            backups=list((home/'state/mise-wrapper-guard/backups').rglob('muse'))
            self.assertEqual(len(backups),1)
            self.assertEqual(backups[0].read_bytes(),original)
    def test_execution_concurrency_and_unknown_formats(self):
        with tempfile.TemporaryDirectory() as d:
            home=pathlib.Path(d)
            env={'PATH':'/usr/bin:/bin', 'HOME':d, 'XDG_STATE_HOME':d+'/state', 'XDG_CONFIG_HOME':d+'/config', 'XDG_DATA_HOME':d+'/data', 'XDG_CACHE_HOME':d+'/cache', 'XDG_RUNTIME_DIR':d+'/run', 'OMARCHY_PATH':d+'/omarchy'}
            make_stock(home, 'codex', 'codex')
            bindir=home/'.local/bin'
            unknown=bindir/'custom'
            unknown.write_text((bindir/'codex').read_text()+'# custom modification\n')
            unknown.chmod(0o755)
            original=unknown.read_bytes()
            (bindir/'linked').symlink_to(unknown)
            subprocess.run(['/usr/bin/python3',str(ROOT/'guard.py'),'--apply'],env=env,check=True)
            self.assertEqual(unknown.read_bytes(),original)
            self.assertTrue((bindir/'linked').is_symlink())
            tools=home/'tools'; tools.mkdir()
            actual=home/'actual'; actual.mkdir()
            tool=actual/'codex'
            tool.write_text('#!/bin/bash\nprintf "<%s>\\n" "$@"\n')
            tool.chmod(0o755)
            # A fixture mise exercises wrapper dispatch, not real installations.
            mise=tools/'mise'
            mise.write_text('''#!/bin/bash
case "$1" in
 use) mkdir "$HOME/busy" || exit 71; sleep 0.05; rmdir "$HOME/busy" ;;
 bin-paths) printf '%s\\n' "$HOME/.local/bin" "$HOME/actual" ;;
 x) shift 3; exec "$@" ;;
 *) exit 72 ;;
esac
''')
            mise.chmod(0o755)
            env['PATH']=str(bindir)+':'+str(tools)+':/usr/bin'
            processes=[subprocess.Popen([str(bindir/'codex'),'two words','literal;$'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for _ in range(6)]
            for p in processes:
                out,err=p.communicate(timeout=10)
                self.assertEqual(p.returncode,0,err)
                self.assertEqual(out,'<two words>\n<literal;$>\n')
            tool.unlink()
            r=subprocess.run([str(bindir/'codex')],env=env,capture_output=True,text=True,timeout=5)
            self.assertEqual(r.returncode,1)
            self.assertIn('could not be resolved safely',r.stderr)
if __name__=='__main__': unittest.main()
