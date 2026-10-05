# Mise wrapper resolution (optional)

Custom user-local workaround, **not an upstream fix or a guarantee against all
future changes**. Disabled by default. Opt in during setup:

```bash
./install.sh --mise-wrapper-resolution
```

Or install just this feature (stable entry point, no package installations):

```bash
./features/mise-wrapper-resolution/install.sh
```

The installer installs `~/.local/share/mise-wrapper-guard/guard.py`, registers
`50-mise-wrapper-guard` with `omarchy hook install post-update`, and applies it
once. It never shadows `omarchy-mise-install` or writes Omarchy package files.
The supported hook installer currently uses `~/.config/omarchy/hooks/post-update.d/`
even when `XDG_CONFIG_HOME` differs; the helper likewise uses the fixed path above.

Only executable, regular, exact stock four-line wrappers in `~/.local/bin` are
rewritten, including Muse bracket-option package specs. They serialize `mise use`
using the shared `${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/mise-use.lock`, then
resolve an absolute package executable through `mise bin-paths`, rejecting
self-resolution before `mise x`. Existing protected wrappers remain unchanged;
symlinks and unfamiliar formats are not rewritten. Unfamiliar mise wrappers
produce warnings. This does not validate or upgrade older protected wrappers.

The exact old generator is retained **only as a non-executable comparison fixture**.
A byte-identical regular `~/.local/bin/omarchy-mise-install` is moved out of PATH
to a unique state backup. An unknown override (including any symlink) is preserved
and installation refuses with a warning: review and move it manually, then retry.
Old `.before-mise-wrapper-resolution` backups are left alone, never restored
blindly. Do not edit wrappers/generators concurrently with installation or updates.

## Limits and manual use

The hook runs **post-update only**, not after individual app installations and not
before update migrations. Apply manually after an app install regenerates a wrapper:

```bash
/usr/bin/python3 "$HOME/.local/share/mise-wrapper-guard/guard.py" --apply
```

Omit `--apply` to audit. Backups and `last-report.txt` live under
`${XDG_STATE_HOME:-$HOME/.local/state}/mise-wrapper-guard/`. Repeated runs preserve
already-protected wrappers and do not duplicate their backups. The hook times out
after 30 seconds, warns on failure/unfamiliar wrappers, and exits successfully so
it does not block updates; review the report rather than assuming protection.
Requires Bash, Python 3, `flock`, `timeout`, and the supported Omarchy hook command.
The installer/guard do not run mise or install packages; launching a protected
wrapper still performs its normal `mise use` operation.

Upstream is tracked in omacom/omarchy#8692. Once the packaged
`omarchy-mise-install` resolves binaries through `mise bin-paths`, the guard
retires itself: it changes nothing and its notification asks for removal.
Wrappers that upstream generates are never flagged or rewritten, and upstream's
migration skips guarded wrappers, so the two do not fight. Then remove only this
hook and helper after reviewing their contents. Keep state backups for recovery; do not restore
the retired generator into PATH. Existing guarded wrappers can remain until
Omarchy regenerates them.

## Tests (isolated HOME/XDG; no installed Omarchy required)

```bash
bash tests/mise-wrapper-resolution-test.sh
bash tests/install-smoke.sh
```
