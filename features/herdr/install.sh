#!/usr/bin/env bash
set -euo pipefail

readonly feature_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly helper_home="$HOME/.local/share/herdr-overrides"

command -v omarchy >/dev/null || { printf '%s\n' 'Omarchy is required.' >&2; exit 1; }
command -v herdr >/dev/null || { printf '%s\n' 'herdr is not installed; Omarchy ships it.' >&2; exit 1; }

install -d "$helper_home"
install -m 644 "$feature_dir/apply-overrides.py" "$helper_home/apply-overrides.py"
install -m 644 "$feature_dir/overrides.toml" "$helper_home/overrides.toml"
install -m 644 "$feature_dir/README.md" "$helper_home/README.md"
omarchy hook install post-update "$feature_dir/50-herdr-overrides"
bash "$feature_dir/50-herdr-overrides" --strict
printf '%s\n' 'Applied herdr overrides (re-applied after every Omarchy update).'
