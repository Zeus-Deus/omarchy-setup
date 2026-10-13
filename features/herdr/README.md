# Herdr setup (optional)

Personal settings layered over Omarchy's defaults, plus the latest Focus and Peek
plugins from their repositories' default branches. Requires Herdr 0.9.1+, Python
3.11+, git, and network access when resolving or installing the latest plugins.

```bash
./install.sh --herdr
# Only Herdr, without changing other desktop settings:
./features/herdr/install.sh
```

## What is saved

- `plugins.toml`: GitHub sources, references (`HEAD` for latest by default), and
  enabled state for `Zeus-Deus/herdr-focus` and `Zeus-Deus/herdr-peek`.
- `overrides.toml`: personal differences from Omarchy's base config: onboarding
  off, status symbols, sidebar width 60, system toasts, Focus's agent/workspace
  sidebar rows and styling, and seven Focus/Peek shortcuts.
- Both plugins currently use their default settings: no plugin `config.toml`
  files were present to copy.

Omarchy still owns the base theme, terminal options, and ordinary keybindings.
No plugin source is vendored. No `plugins.json`, absolute install paths, sessions,
SSH machines, titles, triage state, logs, sockets, caches, or credentials are saved.

## Restore and update behavior

`install-plugins.py` resolves each `HEAD` reference to the latest default-branch
commit on every setup run. It resolves all latest references before changing any
plugins; a failed lookup stops without falling back to an older version. It then
uses `herdr plugin install OWNER/REPO --ref SHA --yes` with that run's resolved
commit and verifies the installed source, commit, and enabled state. Matching
commits are not reinstalled; unrelated plugins are retained. An ID belonging to
a linked or different-source plugin stops installation rather than replacing it.

`apply-overrides.py` merges listed settings without replacing the config file.
It supports multiline values and `[[keys.command]]` plugin shortcuts. Shortcuts
are merged by action identity, not by overwriting the entire command list.
Unrelated settings, bindings, and comments stay intact. A conflicting explicit
shortcut aborts the merge without changing the file. New settings/shortcut
blocks are marked `# omarchy-setup`; changed config is backed up alongside it.
A matching config is left byte-for-byte unchanged.

The installer copies the merge helper and overrides to
`~/.local/share/herdr-overrides/` and registers the `50-herdr-overrides`
post-update hook. The hook only re-applies settings, checks the config, and
reloads a running server when needed. It does not fetch or reinstall plugins,
start a server, or block an Omarchy update. Herdr reports default-key conflicts
through `herdr config check`; resolve those before using the affected shortcut.

## Changing the saved setup

Edit `overrides.toml` for settings/sidebar/shortcuts. In `plugins.toml`, `ref =
"HEAD"` tracks the repository's latest default branch; a full lowercase commit
SHA is still supported if you deliberately want a fixed revision. Change enabled
state there too, then rerun the feature installer. This updates plugins, not the
Herdr application itself. Do not copy a live registry or runtime folders into Git.
Removing a saved entry does not automatically remove installed settings or
uninstall a plugin.

## Removing

Remove `~/.config/omarchy/hooks/post-update.d/50-herdr-overrides` and
`~/.local/share/herdr-overrides/` to stop re-applying settings. Config entries
remain until manually removed or reset with Omarchy. Uninstall plugins separately
with `herdr plugin uninstall focus` / `herdr plugin uninstall peek`; unrelated
plugin state is never deleted by this feature.

## Tests

```bash
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -m unittest discover -s tests -p 'test_herdr_*.py'
bash tests/install-smoke.sh
```
