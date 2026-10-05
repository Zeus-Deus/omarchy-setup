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


def read_overrides(path):
    text = path.read_text()
    tomllib.loads(text)  # reject invalid TOML before touching anything
    entries, section = [], ''
    for number, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        if ARRAY_TABLE.match(line):
            sys.exit(f'{path}:{number}: [[array tables]] are not supported')
        if header := HEADER.match(line):
            section = header.group(1).strip()
            continue
        key = KEY_LINE.match(line)
        if not key:
            sys.exit(f'{path}:{number}: expected a single-line `key = value`')
        value = key.group(2)
        entries.append((section, key.group(1), value, tomllib.loads(f'v = {value}')['v']))
    return entries


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
    last_key = None
    for index in range(start, end):
        match = KEY_LINE.match(lines[index])
        if not match:
            continue
        last_key = index
        if match.group(1) == key:
            lines[index] = wanted
            return
    lines.insert(last_key + 1 if last_key is not None else start, wanted)


def main():
    if len(sys.argv) != 3:
        sys.exit('usage: apply-overrides.py <overrides.toml> <herdr config.toml>')
    overrides, target = Path(sys.argv[1]), Path(sys.argv[2])
    original = target.read_text()
    data = tomllib.loads(original)
    lines = original.splitlines()
    changed = []
    for section, key, value, parsed in read_overrides(overrides):
        if current_value(data, section, key) == parsed:
            continue
        upsert(lines, section, key, value)
        changed.append(f'{section + "." if section else ""}{key} = {value}')
    if not changed:
        return

    updated = '\n'.join(lines) + '\n'
    tomllib.loads(updated)  # never write a config herdr cannot parse
    stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    backup = target.with_name(f'{target.name}.bak.{stamp}')
    backup.write_bytes(original.encode())
    fd, temporary = tempfile.mkstemp(prefix='.config.toml.', dir=target.parent)
    with os.fdopen(fd, 'w') as handle:
        handle.write(updated)
    os.chmod(temporary, target.stat().st_mode & 0o777)
    os.replace(temporary, target)
    print(f'Backed up {target} to {backup.name}')
    for entry in changed:
        print(f'Set {entry}')


if __name__ == '__main__':
    main()
