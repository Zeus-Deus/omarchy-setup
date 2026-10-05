#!/usr/bin/env bash
set -euo pipefail

readonly feature_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly helper_home="$HOME/.local/share/mise-wrapper-guard"
readonly state_home="${XDG_STATE_HOME:-$HOME/.local/state}/mise-wrapper-guard"

command -v omarchy >/dev/null || { printf '%s\n' 'Omarchy is required.' >&2; exit 1; }
install -d "$state_home" "$helper_home"
exec {install_lock_fd}>"$state_home/install.lock"
flock "$install_lock_fd"

# Never replace a customization, or follow even a byte-identical symlink.
readonly generator="$HOME/.local/bin/omarchy-mise-install"
if [[ -e "$generator" || -L "$generator" ]]; then
  if [[ ! -L "$generator" && -f "$generator" ]] &&
      cmp -s "$feature_dir/fixtures/legacy-omarchy-mise-install.txt" "$generator"; then
    install -d "$state_home/backups"
    backup_dir=$(mktemp -d "$state_home/backups/legacy-generator.XXXXXXXX")
    mv -- "$generator" "$backup_dir/omarchy-mise-install"
    printf 'Moved known legacy override out of PATH: %s\n' "$backup_dir/omarchy-mise-install"
  else
    printf 'WARNING: unknown override at %s; left untouched. Review and move it out of PATH manually before retrying.\n' "$generator" >&2
    exit 1
  fi
fi

install -m 644 "$feature_dir/guard.py" "$helper_home/guard.py"
install -m 644 "$feature_dir/README.md" "$helper_home/README.md"
omarchy hook install post-update "$feature_dir/50-mise-wrapper-guard"
/usr/bin/python3 "$helper_home/guard.py" --apply
printf '%s\n' 'Installed the optional user-local mise wrapper guard (post-update only).'
