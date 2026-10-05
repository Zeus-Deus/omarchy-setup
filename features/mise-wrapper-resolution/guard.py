#!/usr/bin/python3
"""Conservative user-local compatibility for Omarchy mise wrappers. No installs."""
import argparse
import datetime
import fcntl
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile

PATTERN = re.compile(r'#!/bin/bash\nexport MISE_MINIMUM_RELEASE_AGE=0\nmise use -g --quiet "([^"\n$`\\]+)" \|\| exit 1\nexec mise x "\1" -- "([A-Za-z0-9_+.-]+)" "\$@"\n')
MARKER = '# mise-wrapper-guard v1 (user-local compatibility)\n'
RETIRED = ('WARNING upstream fix detected: omarchy-mise-install now resolves binaries itself; '
           'nothing was changed. Remove this feature (see its README).')

def upstream_fixed():
    # Only the packaged generator counts; never a user override in ~/.local/bin.
    generator = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy')) / 'bin/omarchy-mise-install'
    try:
        return 'mise bin-paths' in generator.read_text(errors='replace')
    except OSError:
        return False

def protect(text):
    match = PATTERN.fullmatch(text)
    if not match:
        return None
    package, binary = match.groups()
    if binary in ('.', '..') or binary.startswith('-') or package.startswith('-'):
        return None
    pkg, exe = shlex.quote(package), shlex.quote(binary)
    return f'''#!/bin/bash
{MARKER}export MISE_MINIMUM_RELEASE_AGE=0
lock="${{XDG_STATE_HOME:-$HOME/.local/state}}/omarchy/mise-use.lock"
mkdir -p "${{lock%/*}}" || exit 1
flock "$lock" mise use -g --quiet {pkg} || exit 1
bin_paths=$(mise bin-paths {pkg}) || exit 1
bin_path=
while IFS= read -r bin_dir; do
  [[ $bin_dir == /* ]] || continue
  candidate="$bin_dir"/{exe}
  if [[ -f $candidate && -x $candidate && ! $candidate -ef "$0" ]]; then
    bin_path=$candidate
    break
  fi
done <<<"$bin_paths"
if [[ -z $bin_path ]]; then
  printf '%s\\n' 'mise wrapper: package executable could not be resolved safely' >&2
  exit 1
fi
exec mise x {pkg} -- "$bin_path" "$@"
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='back up and protect recognized stock wrappers (default: audit only)')
    args = parser.parse_args()
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'mise-wrapper-guard'
    state.mkdir(parents=True, exist_ok=True)
    with (state/'guard.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if upstream_fixed():
            (state/'last-report.txt').write_text(RETIRED + '\n')
            print(RETIRED)
            return
        messages = []
        bindir = Path.home()/'.local/bin'
        for p in sorted(bindir.iterdir()) if bindir.exists() else []:
            if p.is_symlink() or not p.is_file() or not os.access(p, os.X_OK) or p.stat().st_size > 16384:
                continue
            if '.bak' in p.name or '.before-' in p.name or p.name.startswith('.'):
                continue
            raw = p.read_bytes()
            try:
                text = raw.decode('utf-8')
            except UnicodeDecodeError:
                if b'mise use' in raw and b'mise x' in raw:
                    messages.append(f'WARNING {p.name}: non-UTF-8 wrapper; left untouched, review needed')
                continue
            if 'mise use' not in text or 'mise x' not in text:
                continue
            # Upstream-generated wrappers that already resolve their binary count too.
            if MARKER in text or 'mise bin-paths' in text:
                messages.append(f'PRESERVED {p.name}: existing protection')
                continue
            fixed = protect(text)
            if fixed is None:
                messages.append(f'WARNING {p.name}: unfamiliar wrapper; left untouched, review needed')
                continue
            messages.append(f'{"PROTECTED" if args.apply else "WOULD PROTECT"} {p.name}')
            if not args.apply:
                continue
            subprocess.run(['/bin/bash', '-n'], input=fixed, text=True, check=True, capture_output=True)
            stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
            backup = state/'backups'/stamp/p.name
            backup.parent.mkdir(parents=True)
            backup.write_bytes(raw)
            backup.chmod(p.stat().st_mode & 0o777)
            fd, temp = tempfile.mkstemp(prefix='.mise-guard-', dir=bindir)
            try:
                with os.fdopen(fd, 'w') as f:
                    f.write(fixed)
                    f.flush()
                    os.fsync(f.fileno())
                os.chmod(temp, p.stat().st_mode & 0o777)
                if p.is_symlink() or p.read_bytes() != raw:
                    raise RuntimeError(f'{p.name} changed during inspection; refusing replacement')
                os.replace(temp, p)
            finally:
                if os.path.exists(temp):
                    os.unlink(temp)
        report = '\n'.join(messages) + '\n'
        (state/'last-report.txt').write_text(report)
        print(report, end='')

if __name__ == '__main__':
    main()
