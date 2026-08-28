#!/usr/bin/env bash

set -euo pipefail

readonly repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT

export HOME="$fixture/home"
readonly bin_home="$HOME/.local/bin"
readonly stub_bin="$fixture/stub-bin"
readonly package_bin="$fixture/package-bin"
readonly mise_log="$fixture/mise.log"
install -d "$bin_home" "$stub_bin" "$package_bin"

cat >"$bin_home/opencode" <<'WRAPPER'
#!/bin/bash
export MISE_MINIMUM_RELEASE_AGE=0
lock="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/mise-use.lock"
mkdir -p "${lock%/*}"
flock "$lock" mise use -g --quiet "opencode" || exit 1
exec mise x "opencode" -- "opencode" "$@"
WRAPPER
cat >"$bin_home/pi" <<'WRAPPER'
#!/bin/bash
export MISE_MINIMUM_RELEASE_AGE=0
mise use -g --quiet "pi" || exit 1
exec mise x "pi" -- "pi" "$@"
WRAPPER
cat >"$bin_home/codex" <<'WRAPPER'
#!/bin/bash
# customized
exit 0
WRAPPER
cat >"$bin_home/claude" <<'WRAPPER'
#!/bin/bash
export MISE_MINIMUM_RELEASE_AGE=0
mise use -g --quiet "claude" || exit 1
exec mise x "claude" -- "claude" "$@"
WRAPPER
printf '\n' >>"$bin_home/claude"
ln -s /usr/bin/true "$bin_home/gh"
chmod +x "$bin_home/opencode" "$bin_home/pi" "$bin_home/codex" "$bin_home/claude"
custom_before=$(<"$bin_home/codex")
claude_before=$(sha256sum "$bin_home/claude")

for unsafe_package in --help -q ../evil ./evil github:owner/../evil /absolute github:owner//repo; do
  if HOME="$HOME" "$repo_dir/features/mise-wrapper-resolution/omarchy-mise-install" "$unsafe_package" unsafe pi >/dev/null 2>&1; then
    printf 'Expected package name %s to be rejected.\n' "$unsafe_package" >&2
    exit 1
  fi
done
if HOME="$HOME" "$repo_dir/features/mise-wrapper-resolution/omarchy-mise-install" 'bad"package' unsafe pi >/dev/null 2>&1; then
  printf '%s\n' 'Expected an unsafe package name to be rejected.' >&2
  exit 1
fi
if HOME="$HOME" "$repo_dir/features/mise-wrapper-resolution/omarchy-mise-install" pi 'bad"command' pi >/dev/null 2>&1; then
  printf '%s\n' 'Expected an unsafe command name to be rejected.' >&2
  exit 1
fi
if HOME="$HOME" "$repo_dir/features/mise-wrapper-resolution/omarchy-mise-install" pi unsafe 'bad"bin' >/dev/null 2>&1; then
  printf '%s\n' 'Expected an unsafe bin name to be rejected.' >&2
  exit 1
fi
for unsafe_name in . ..; do
  if HOME="$HOME" "$repo_dir/features/mise-wrapper-resolution/omarchy-mise-install" pi "$unsafe_name" pi >/dev/null 2>&1; then
    printf 'Expected command name %s to be rejected.\n' "$unsafe_name" >&2
    exit 1
  fi
  if HOME="$HOME" "$repo_dir/features/mise-wrapper-resolution/omarchy-mise-install" pi unsafe "$unsafe_name" >/dev/null 2>&1; then
    printf 'Expected bin name %s to be rejected.\n' "$unsafe_name" >&2
    exit 1
  fi
done
[[ ! -e "$bin_home/unsafe" ]]
grep -qF 'generator_temporary=$(mktemp "$bin_home/.omarchy-mise-install.XXXXXX")' "$repo_dir/features/mise-wrapper-resolution/install.sh"
grep -qF 'mv -f -- "$generator_temporary" "$generator"' "$repo_dir/features/mise-wrapper-resolution/install.sh"
grep -qF 'flock "$lock_fd"' "$repo_dir/features/mise-wrapper-resolution/install.sh"
grep -qF 'temporary=$(mktemp "$HOME/.local/bin/.${command}.XXXXXX")' "$repo_dir/features/mise-wrapper-resolution/omarchy-mise-install"
grep -qF 'mv -f -- "$temporary" "$HOME/.local/bin/$command"' "$repo_dir/features/mise-wrapper-resolution/omarchy-mise-install"
! grep -qF 'rm -f "$HOME/.local/bin/$command"' "$repo_dir/features/mise-wrapper-resolution/omarchy-mise-install"
printf '%s\n' '#!/usr/bin/env bash' 'printf custom-generator' >"$bin_home/omarchy-mise-install"
chmod +x "$bin_home/omarchy-mise-install"

bash "$repo_dir/features/mise-wrapper-resolution/install.sh"

[[ $("$bin_home/omarchy-mise-install.before-mise-wrapper-resolution") == custom-generator ]]

grep -qF 'bin_paths=$(mise bin-paths "opencode")' "$bin_home/opencode"
grep -qF 'flock "$lock" mise use -g --quiet "opencode"' "$bin_home/opencode"
grep -qF '[[ -n $bin_dir ]] || continue' "$bin_home/opencode"
grep -qF '[[ -f "$bin_dir/pi" && -x "$bin_dir/pi" ]]' "$bin_home/pi"
[[ $(stat -c %a "$bin_home/opencode") == 755 ]]
[[ $(stat -c %a "$bin_home/pi") == 755 ]]
[[ $(<"$bin_home/codex") == "$custom_before" ]]
[[ $(sha256sum "$bin_home/claude") == "$claude_before" ]]
[[ -L "$bin_home/gh" && $(readlink "$bin_home/gh") == /usr/bin/true ]]

hash_before=$(sha256sum "$bin_home/omarchy-mise-install" "$bin_home/opencode" "$bin_home/pi")
bash "$repo_dir/features/mise-wrapper-resolution/install.sh"
hash_after=$(sha256sum "$bin_home/omarchy-mise-install" "$bin_home/opencode" "$bin_home/pi")
[[ $hash_before == "$hash_after" ]]

cat >"$stub_bin/mise" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$MISE_TEST_LOG"
case "$1" in
  use) exit 0 ;;
  bin-paths) printf '%s\n' '' "$MISE_TEST_PACKAGE_BIN" ;;
  x)
    shift 2
    [[ $1 == -- ]] || exit 2
    shift
    exec "$@"
    ;;
  *) exit 3 ;;
esac
STUB
cat >"$package_bin/pi" <<'TOOL'
#!/usr/bin/env bash
printf '%s\n' 'correct-package'
TOOL
chmod +x "$stub_bin/mise" "$package_bin/pi"
export MISE_TEST_LOG="$mise_log"
export MISE_TEST_PACKAGE_BIN="$package_bin"

output=$(PATH="$bin_home:$stub_bin:/usr/bin" "$bin_home/pi")
[[ $output == correct-package ]]
grep -Fxq 'use -g --quiet pi' "$mise_log"
grep -Fxq 'bin-paths pi' "$mise_log"
grep -Fxq "x pi -- $package_bin/pi" "$mise_log"

printf '%s\n' 'Mise wrapper resolution test passed.'
