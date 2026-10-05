# herdr overrides (optional)

Personal [herdr](https://herdr.dev) settings layered on top of the config
Omarchy ships. Opt in during setup:

```bash
./install.sh --herdr
```

Or install just this feature:

```bash
./features/herdr/install.sh
```

## How it stays update-safe

Omarchy owns the base: it ships herdr as a package and seeds
`~/.config/herdr/config.toml` only when that file is missing. This feature never
replaces the file. `apply-overrides.py` merges each key from `overrides.toml`
into it, replacing a differing value, adding a missing key to its section, and
keeping every other line, including settings saved from herdr's own UI. Lines
it writes end in `# omarchy-setup`, and the previous file is kept as
`config.toml.bak.<timestamp>` next to it. Nothing is written when the config
already matches.

The installer copies the helper and overrides to
`~/.local/share/herdr-overrides/` and registers `50-herdr-overrides` with
`omarchy hook install post-update`. After each update, the hook re-applies the
overrides, so `omarchy refresh herdr` (which resets the file to Omarchy's
default) only lasts until the next update or install. When something changed, it
runs `herdr config check` and reloads a running server. The hook never blocks an
update.

## Changing settings

Add a single-line `key = value` under its `[section]` in `overrides.toml`, with
comments on their own lines (no `[[array tables]]` or multi-line values). Check
the setting and its default with `herdr --default-config`, then rerun the
installer.

| Setting | Value | Why |
| --- | --- | --- |
| `ui.sidebar_max_width` | `60` | The default limit of 36 columns stops the sidebar too narrow for workspace and branch names. |

## Removing

Delete `~/.config/omarchy/hooks/post-update.d/50-herdr-overrides` and
`~/.local/share/herdr-overrides/`. Lines marked `# omarchy-setup` stay in the
config until removed by hand or `omarchy refresh herdr`.

## Tests

```bash
/usr/bin/python3 -m unittest discover -s tests -p 'test_herdr_*.py'
bash tests/install-smoke.sh
```
