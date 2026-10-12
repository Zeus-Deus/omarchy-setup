#!/usr/bin/python3
"""Merge overrides.toml into herdr's config.toml without replacing the file.

Edits the target line by line, the way herdr's own settings writer does: a key
whose value differs is replaced, a missing key is added to its section, and a
missing section is appended. Comments and every other line are kept. Prints
the keys it changed and writes nothing when the config already matches.
"""
import datetime
import os
from pathlib import Path
import re
import sys
import tempfile
import tomllib

MARKER = '# omarchy-setup'
HEADER = re.compile(r'^\s*\[([^\[\]]+)\]\s*(#.*)?$')
ARRAY_TABLE = re.compile(r'^\s*\[\[')
KEY_LINE = re.compile(r'^\s*([A-Za-z0-9_-]+)\s*=\s*(.*?)\s*$')


def value_span(lines, start):
    """Read a TOML value, including multiline arrays, from a key line."""
    match = KEY_LINE.match(lines[start])
    assert match is not None
    value = match.group(2)
    end = start + 1
    while True:
        try:
            return end, value, tomllib.loads(f'v = {value}')['v']
        except tomllib.TOMLDecodeError:
            if end >= len(lines):
                raise
            value += '\n' + lines[end]
            end += 1


def read_overrides(path):
    text = path.read_text()
    parsed = tomllib.loads(text)  # reject invalid TOML before touching anything
    bindings = parsed.get('keys', {}).get('command', [])
    entries, section = [], ''
    lines, index = text.splitlines(), 0
    while index < len(lines):
        line = lines[index]
        index += 1
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        if ARRAY_TABLE.match(line):
            if stripped != '[[keys.command]]':
                sys.exit(f'{path}:{index}: only [[keys.command]] array tables are supported')
            section = 'keys.command[]'
            continue
        if header := HEADER.match(line):
            section = header.group(1).strip()
            continue
        key = KEY_LINE.match(line)
        if not key:
            sys.exit(f'{path}:{index}: expected `key = value`')
        index, value, parsed = value_span(lines, index - 1)
        if section != 'keys.command[]':
            if section == 'keys' and key.group(1) == 'command':
                sys.exit('Use [[keys.command]] for plugin bindings, not an inline command array')
            entries.append((section, key.group(1), value, parsed))
    return entries, bindings


def current_value(data, section, key):
    for part in section.split('.') if section else []:
        data = data.get(part)
        if not isinstance(data, dict):
            return None
    return data.get(key)


def section_bounds(lines, section):
    """Return [start, end) of the lines belonging to `section`, or None."""
    start = 0
    if section:
        for index, line in enumerate(lines):
            header = HEADER.match(line)
            if header and header.group(1).strip() == section:
                start = index + 1
                break
        else:
            return None
    end = start
    while end < len(lines) and not (HEADER.match(lines[end]) or ARRAY_TABLE.match(lines[end])):
        end += 1
    return start, end


def upsert(lines, section, key, value):
    wanted = f'{key} = {value}  {MARKER}'
    bounds = section_bounds(lines, section)
    if bounds is None:
        if lines and lines[-1].strip():
            lines.append('')
        lines.extend([f'[{section}]', wanted])
        return
    start, end = bounds
    index, insert_at = start, start
    while index < end:
        match = KEY_LINE.match(lines[index])
        if not match:
            index += 1
            continue
        value_end, _, _ = value_span(lines, index)
        if match.group(1) == key:
            lines[index:value_end] = wanted.splitlines()
            return
        insert_at = value_end
        index = value_end
    lines[insert_at:insert_at] = wanted.splitlines()


def merge_bindings(lines, bindings):
    """Merge plugin actions by command identity; never steal another shortcut."""
    import json

    changed = []
    seen = set()
    for wanted in bindings:
        if (wanted.get('type') != 'plugin_action'
                or not all(isinstance(v, str) for v in wanted.values())
                or not wanted.get('key') or not wanted.get('command')):
            sys.exit('Plugin bindings require string key/type/command values')
        key = wanted['key']
        if key in seen:
            sys.exit(f'Duplicate plugin shortcut: {key}')
        seen.add(key)
        data = tomllib.loads('\n'.join(lines))
        existing = data.get('keys', {}).get('command', [])
        matches = [b for b in existing if b.get('type') == 'plugin_action'
                   and b.get('command') == wanted['command']]
        if len(matches) > 1:
            sys.exit(f'Duplicate existing plugin action: {wanted["command"]}')
        for name, value in data.get('keys', {}).items():
            if name != 'command' and key in (value if isinstance(value, list) else [value]):
                sys.exit(f'Plugin shortcut {key} conflicts with keys.{name}; config unchanged')
        for binding in existing:
            if binding not in matches and key == binding.get('key'):
                sys.exit(f'Plugin shortcut {key} is already assigned; config unchanged')
        if matches and all(matches[0].get(k) == v for k, v in wanted.items()):
            continue
        if matches:
            # Keep comments and unowned fields in the matching array-table block.
            found = False
            for start, line in enumerate(lines):
                if line.strip().split('#', 1)[0].strip() != '[[keys.command]]':
                    continue
                end = start + 1
                while end < len(lines) and not (HEADER.match(lines[end]) or ARRAY_TABLE.match(lines[end])):
                    end += 1
                block = lines[start:end]
                parsed = tomllib.loads('\n'.join(block))['keys']['command'][0]
                if parsed.get('type') != 'plugin_action' or parsed.get('command') != wanted['command']:
                    continue
                fields = block[1:]
                for name, value in wanted.items():
                    upsert(fields, '', name, json.dumps(value, ensure_ascii=False))
                lines[start:end] = [block[0], *fields]
                found = True
                break
            if not found:
                sys.exit('Cannot update inline command arrays; use [[keys.command]]; config unchanged')
        else:
            lines.extend(['', f'[[keys.command]]  {MARKER}'])
            lines.extend(f'{k} = {json.dumps(v, ensure_ascii=False)}' for k, v in wanted.items())
        changed.append(f'plugin shortcut {key} -> {wanted["command"]}')
    return changed


def main():
    if len(sys.argv) != 3:
        sys.exit('usage: apply-overrides.py <overrides.toml> <herdr config.toml>')
    overrides, target = Path(sys.argv[1]), Path(sys.argv[2])
    original = target.read_text()
    data = tomllib.loads(original)
    lines = original.splitlines()
    changed = []
    entries, bindings = read_overrides(overrides)
    for section, key, value, parsed in entries:
        if current_value(data, section, key) == parsed:
            continue
        upsert(lines, section, key, value)
        changed.append(f'{section + "." if section else ""}{key}')
    changed.extend(merge_bindings(lines, bindings))
    if not changed:
        return

    updated = '\n'.join(lines) + '\n'
    tomllib.loads(updated)  # never write a config herdr cannot parse
    mode = target.stat().st_mode & 0o777
    stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    backup_fd, backup_path = tempfile.mkstemp(prefix=f'{target.name}.bak.{stamp}.', dir=target.parent)
    backup = Path(backup_path)
    with os.fdopen(backup_fd, 'w') as handle:
        handle.write(original)
    os.chmod(backup, mode)
    fd, temporary = tempfile.mkstemp(prefix='.config.toml.', dir=target.parent)
    try:
        with os.fdopen(fd, 'w') as handle:
            handle.write(updated)
        os.chmod(temporary, mode)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print(f'Backed up {target} to {backup.name}')
    for entry in changed:
        print(f'Set {entry}')


if __name__ == '__main__':
    main()
