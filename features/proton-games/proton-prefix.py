#!/usr/bin/env python3
"""Per-game settings in a Steam Proton prefix, edited offline in user.reg."""

import argparse
import os
import re
import shutil
import sys
import time
import tomllib
import uuid
from pathlib import Path

PULSE = r'Software\Wine\Drivers\winepulse.drv'
RENDER_DEVICES = PULSE + '\\devices\\0,'
APP_DEFAULTS = r'Software\Wine\AppDefaults'
GAME_KEYS = {'appid', 'name', 'exe', 'grab_pointer', 'output'}
HEADER = re.compile(r'^\[(.*)\](?: \d+)?$')


class TweakError(Exception):
    pass


# --- registry text -----------------------------------------------------------

def _esc(value):
    return value.replace('\\', '\\\\').replace('"', '\\"')


def _unesc(value):
    return re.sub(r'\\(.)', r'\1', value)


def _key_of(line):
    match = HEADER.match(line)
    return _unesc(match[1]) if match else None


def _section(lines, key):
    """Line span (header, end) of a key's section; end excludes trailing blanks."""
    for start, line in enumerate(lines):
        found = _key_of(line)
        if found is None or found.lower() != key.lower():
            continue
        end = start + 1
        while end < len(lines) and not lines[end].startswith('['):
            end += 1
        while end > start + 1 and not lines[end - 1].strip():
            end -= 1
        return start, end
    return None


def _value_line(lines, span, name):
    prefix = f'"{_esc(name)}"='.lower()
    for index in range(span[0] + 1, span[1]):
        if lines[index].lower().startswith(prefix):
            return index
    return None


def get_value(text, key, name):
    lines = text.split('\n')
    span = _section(lines, key)
    index = _value_line(lines, span, name) if span else None
    if index is None:
        return None
    match = re.match(r'^"(?:[^"\\]|\\.)*"="((?:[^"\\]|\\.)*)"$', lines[index])
    return _unesc(match[1]) if match else lines[index].split('=', 1)[1]


def set_value(text, key, name, value):
    lines = text.split('\n')
    entry = f'"{_esc(name)}"="{_esc(value)}"'
    span = _section(lines, key)
    if span is None:
        now = time.time()
        filetime = int((now + 11644473600) * 10_000_000)
        body = text if text.endswith('\n') else text + '\n'
        if not body.endswith('\n\n'):
            body += '\n'
        header = '[' + _esc(key) + ']'
        return f'{body}{header} {int(now)}\n#time={filetime:x}\n{entry}\n'
    index = _value_line(lines, span, name)
    if index is None:
        lines.insert(span[1], entry)
    else:
        lines[index] = entry
    return '\n'.join(lines)


def remove_value(text, key, name):
    lines = text.split('\n')
    span = _section(lines, key)
    index = _value_line(lines, span, name) if span else None
    if index is None:
        return text
    del lines[index]
    return '\n'.join(lines)


def render_outputs(text):
    """Sink name -> Windows endpoint id, for outputs this prefix has seen."""
    lines = text.split('\n')
    found = {}
    for index, line in enumerate(lines):
        key = _key_of(line)
        if key is None or not key.lower().startswith(RENDER_DEVICES.lower()):
            continue
        sink = key[len(RENDER_DEVICES):]
        if not sink:
            continue
        span = _section(lines, key)
        guid = _value_line(lines, span, 'guid')
        if guid is None:
            continue
        raw = bytes.fromhex(lines[guid].split('hex:', 1)[1].replace(',', ''))
        # Wine compares endpoint ids case-sensitively and expects upper case.
        found[sink] = '{0.0.0.00000000}.{%s}' % str(uuid.UUID(bytes_le=raw)).upper()
    return found


# --- changes -----------------------------------------------------------------

def output_change(sink):
    def change(text):
        if sink == 'default':
            return remove_value(text, PULSE, 'DefaultOutput')
        outputs = render_outputs(text)
        if sink not in outputs:
            known = ', '.join(sorted(outputs)) or 'none'
            raise TweakError(
                f'output {sink!r} is unknown to this prefix (known: {known}). '
                'Launch the game once with the device connected, then retry.')
        return set_value(text, PULSE, 'DefaultOutput', outputs[sink])
    return change


def grab_pointer_change(exe, enabled):
    key = f'{APP_DEFAULTS}\\{exe}\\X11 Driver'

    def change(text):
        if enabled:  # Wine's default
            return remove_value(text, key, 'GrabPointer')
        return set_value(text, key, 'GrabPointer', 'N')
    return change


def game_changes(exe=None, grab_pointer=None, output=None):
    changes = []
    if grab_pointer is not None:
        if not exe:
            raise TweakError('grab_pointer needs the game executable name (exe)')
        changes.append(grab_pointer_change(exe, grab_pointer))
    if output is not None:
        changes.append(output_change(output))
    if not changes:
        raise TweakError('nothing to set')
    return changes


# --- prefix ------------------------------------------------------------------

def find_prefix(appid, steam_root):
    roots = [steam_root] if steam_root else [
        Path.home() / '.steam/steam', Path.home() / '.local/share/Steam']
    libraries = []
    for root in roots:
        libraries.append(root)
        index = root / 'steamapps/libraryfolders.vdf'
        if index.is_file():
            libraries += [Path(path) for path in re.findall(
                r'"path"\s+"([^"]+)"', index.read_text(errors='replace'))]
    for library in dict.fromkeys(path.resolve() for path in libraries):
        prefix = library / 'steamapps/compatdata' / str(appid) / 'pfx'
        if (prefix / 'user.reg').is_file():
            return prefix
    return None


def prefix_in_use(prefix, proc):
    wanted = {b'WINEPREFIX': prefix.resolve(),
              b'STEAM_COMPAT_DATA_PATH': prefix.parent.resolve()}
    for environ in proc.glob('[0-9]*/environ'):
        try:
            items = environ.read_bytes().split(b'\0')
        except OSError:
            continue
        for item in items:
            name, _, value = item.partition(b'=')
            if name in wanted and Path(os.fsdecode(value)).resolve() == wanted[name]:
                return True
    return False


def edit_prefix(appid, prefix, changes, options):
    """Apply changes to user.reg. Returns 'unchanged', 'would change' or the backup path."""
    registry = prefix / 'user.reg'
    raw = registry.read_bytes()
    old = raw.decode('utf-8', 'surrogateescape')
    new = old
    for change in changes:
        new = change(new)
    if new == old:
        return 'unchanged'
    if options.dry_run:
        return 'would change'
    if prefix_in_use(prefix, options.proc):
        raise TweakError('the game or its Proton session is still running; close it first')
    stamp = time.strftime('%Y%m%d-%H%M%S')
    backup_dir = options.state_dir / str(appid) / stamp
    suffix = 0
    while backup_dir.exists():
        suffix += 1
        backup_dir = options.state_dir / str(appid) / f'{stamp}-{suffix}'
    backup_dir.mkdir(parents=True)
    (backup_dir / 'user.reg').write_bytes(raw)
    temporary = registry.with_name('user.reg.proton-prefix-tmp')
    temporary.write_bytes(new.encode('utf-8', 'surrogateescape'))
    shutil.copymode(registry, temporary)
    os.replace(temporary, registry)
    return backup_dir / 'user.reg'


def short(path):
    try:
        return '~/' + str(Path(path).relative_to(Path.home()))
    except ValueError:
        return str(path)


def describe(result):
    return result if isinstance(result, str) else f'changed (backup: {short(result)})'


def require_prefix(appid, options):
    prefix = find_prefix(appid, options.steam_root)
    if prefix is None:
        raise TweakError(f'no Proton prefix for app {appid}; launch the game once first')
    return prefix


# --- commands ----------------------------------------------------------------

def cmd_show(options):
    prefix = require_prefix(options.appid, options)
    text = (prefix / 'user.reg').read_bytes().decode('utf-8', 'surrogateescape')
    outputs = render_outputs(text)
    current = get_value(text, PULSE, 'DefaultOutput')
    sink = next((name for name, ident in outputs.items() if ident == current), None)
    print(f'prefix: {short(prefix)}')
    if current is None:
        print('output: system default')
    else:
        print(f'output: {sink or "UNKNOWN endpoint " + current}')
    grabs = []
    for line in text.split('\n'):
        key = _key_of(line)
        if key and key.lower().startswith(APP_DEFAULTS.lower() + '\\') \
                and key.lower().endswith('\\x11 driver'):
            value = get_value(text, key, 'GrabPointer')
            if value is not None:
                grabs.append(f'{key.split(chr(92))[-2]}={value}')
    print('grab-pointer overrides: ' + (', '.join(grabs) or 'none'))
    print('known outputs:')
    for name in sorted(outputs):
        print(f'  {name}')
    return 0


def cmd_set(options):
    grab = None if options.grab_pointer is None else options.grab_pointer == 'on'
    changes = game_changes(options.exe, grab, options.output)
    prefix = require_prefix(options.appid, options)
    print(f'{options.appid}: {describe(edit_prefix(options.appid, prefix, changes, options))}')
    return 0


def cmd_apply(options):
    with open(options.file, 'rb') as handle:
        games = tomllib.load(handle).get('game', [])
    if not games:
        raise TweakError(f'{options.file} lists no [[game]] entries')
    failed = False
    for game in games:
        label = f"{game.get('appid')} {game.get('name', '')}".strip()
        try:
            unknown = set(game) - GAME_KEYS
            if unknown or 'appid' not in game:
                raise TweakError(f'bad entry (unknown or missing keys: {sorted(unknown) or "appid"})')
            changes = game_changes(game.get('exe'), game.get('grab_pointer'), game.get('output'))
            prefix = find_prefix(game['appid'], options.steam_root)
            if prefix is None:
                print(f'{label}: skipped, no Proton prefix yet (launch the game once, then rerun)')
                continue
            print(f'{label}: {describe(edit_prefix(game["appid"], prefix, changes, options))}')
        except TweakError as error:
            failed = True
            print(f'{label}: FAILED: {error}', file=sys.stderr)
    return 1 if failed else 0


def main(argv=None):
    state_home = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state')
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument('--steam-root', type=Path, help='Steam directory (default: auto-detect)')
    common.add_argument('--state-dir', type=Path, default=state_home / 'proton-prefix-tweaks',
                        help='where registry backups go')
    common.add_argument('--proc', type=Path, default=Path('/proc'), help=argparse.SUPPRESS)
    writing = argparse.ArgumentParser(add_help=False)
    writing.add_argument('--dry-run', action='store_true', help='report without writing')

    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    show = commands.add_parser('show', parents=[common], help='show a prefix and its known outputs')
    show.add_argument('appid', type=int)
    show.set_defaults(run=cmd_show)
    one = commands.add_parser('set', parents=[common, writing], help='change one game')
    one.add_argument('appid', type=int)
    one.add_argument('--output', metavar='SINK', help="PulseAudio sink name, or 'default'")
    one.add_argument('--exe', help='game executable name, e.g. Game.exe')
    one.add_argument('--grab-pointer', choices=['on', 'off'],
                     help="'off' stops Wine grabbing the pointer for --exe")
    one.set_defaults(run=cmd_set)
    many = commands.add_parser('apply', parents=[common, writing], help='apply games.toml')
    many.add_argument('file', nargs='?', type=Path,
                      default=Path(__file__).resolve().parent / 'games.toml')
    many.set_defaults(run=cmd_apply)

    options = parser.parse_args(argv)
    try:
        return options.run(options)
    except TweakError as error:
        print(f'error: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
