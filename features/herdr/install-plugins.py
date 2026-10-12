#!/usr/bin/python3
"""Restore pinned plugins through Herdr's installer, then read them back."""
import json
from pathlib import Path
import re
import subprocess
import sys
import tomllib


def run(*args, capture=False):
    result = subprocess.run(['herdr', *args], check=True, text=True,
                            stdout=subprocess.PIPE if capture else None, timeout=180)
    return result.stdout or ''


def installed():
    response = json.loads(run('plugin', 'list', '--json', capture=True))
    plugins = response['result']['plugins']
    result = {p['plugin_id']: p for p in plugins}
    if len(result) != len(plugins):
        raise ValueError('Herdr returned duplicate plugin IDs')
    return result


def matches_source(current, wanted):
    source = current.get('source', {})
    return (source.get('kind') == 'github'
            and f'{source.get("owner")}/{source.get("repo")}' == wanted['source']
            and not source.get('subdir'))


def read_pins(path):
    document = tomllib.loads(path.read_text())
    minimum = document['min_herdr_version']
    if not re.fullmatch(r'\d+\.\d+\.\d+', minimum):
        raise ValueError('Invalid minimum Herdr version')
    pins = document['plugins']
    seen = set()
    for pin in pins:
        if set(pin) != {'id', 'source', 'ref', 'enabled'}:
            raise ValueError('Plugin pins require only id/source/ref/enabled')
        if (not re.fullmatch(r'[a-z0-9_-]+', pin['id'])
                or not re.fullmatch(r'[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+', pin['source'])
                or not re.fullmatch(r'[0-9a-f]{40}', pin['ref'])
                or not isinstance(pin['enabled'], bool)):
            raise ValueError('Invalid plugin pin; use a full lowercase commit SHA')
        if pin['id'] in seen:
            raise ValueError(f'Duplicate plugin ID: {pin["id"]}')
        seen.add(pin['id'])
    return minimum, pins


def main():
    if len(sys.argv) != 2:
        raise ValueError('usage: install-plugins.py <plugins.toml>')
    minimum, pins = read_pins(Path(sys.argv[1]))
    version = re.fullmatch(r'herdr (\d+)\.(\d+)\.(\d+)(?:[-+][^\s]+)?\s*',
                           run('--version', capture=True))
    if not version or tuple(map(int, version.groups())) < tuple(map(int, minimum.split('.'))):
        raise ValueError(f'Herdr {minimum}+ is required')
    current = installed()
    # Preflight all IDs before changing anything; never replace another owner's plugin.
    for pin in pins:
        item = current.get(pin['id'])
        if item and not matches_source(item, pin):
            raise ValueError(f'{pin["id"]} belongs to a different or linked source; left unchanged')
    for pin in pins:
        item = current.get(pin['id'])
        if not item or item['source'].get('resolved_commit') != pin['ref']:
            run('plugin', 'install', pin['source'], '--ref', pin['ref'], '--yes')
        item = installed().get(pin['id'])
        if not item or not matches_source(item, pin) or item['source'].get('resolved_commit') != pin['ref']:
            raise ValueError(f'Could not verify installed revision for {pin["id"]}')
        if item.get('enabled') != pin['enabled']:
            run('plugin', 'enable' if pin['enabled'] else 'disable', pin['id'])
        verified = installed().get(pin['id'])
        if (not verified or not matches_source(verified, pin)
                or verified['source'].get('resolved_commit') != pin['ref']
                or verified.get('enabled') != pin['enabled']):
            raise ValueError(f'Could not verify enabled state for {pin["id"]}')
        print(f'Verified {pin["id"]} at {pin["ref"]}')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        sys.exit(f'herdr plugins: {error}')
