#!/usr/bin/env bash

set -euo pipefail

readonly feature_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly bin_home="${HOME}/.local/bin"
readonly generator="$bin_home/omarchy-mise-install"
readonly generator_backup="$generator.before-mise-wrapper-resolution"
readonly state_home="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/mise-wrapper-resolution"

install -d "$bin_home" "$state_home"
exec {install_lock_fd}>"$state_home/install.lock"
flock "$install_lock_fd"

legacy_plain() {
  local package="$1" bin="$2"
  printf '%s\n' \
    '#!/bin/bash' \
    'export MISE_MINIMUM_RELEASE_AGE=0' \
    "mise use -g --quiet \"$package\" || exit 1" \
    "exec mise x \"$package\" -- \"$bin\" \"\$@\""
}

legacy_locked() {
  local package="$1" bin="$2"
  printf '%s\n' \
    '#!/bin/bash' \
    'export MISE_MINIMUM_RELEASE_AGE=0' \
    'lock="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/mise-use.lock"' \
    'mkdir -p "${lock%/*}"' \
    "flock \"\$lock\" mise use -g --quiet \"$package\" || exit 1" \
    "exec mise x \"$package\" -- \"$bin\" \"\$@\""
}

repair_wrapper() {
  local package="$1" command="$2" bin="$3"
  local wrapper="$bin_home/$command" current plain locked lock_fd

  exec {lock_fd}>"$state_home/$command.lock"
  flock "$lock_fd"

  if [[ -f "$wrapper" && ! -L "$wrapper" ]] &&
      (( $(wc -c <"$wrapper") <= 8192 )); then
    current=$(cat -- "$wrapper"; printf '\001')
    plain=$(legacy_plain "$package" "$bin"; printf '\001')
    locked=$(legacy_locked "$package" "$bin"; printf '\001')

    if [[ $current == "$plain" || $current == "$locked" ]]; then
      "$generator" "$package" "$command" "$bin"
    fi
  fi

  exec {lock_fd}>&-
}

if [[ ( -e $generator || -L $generator ) &&
      ! -e $generator_backup && ! -L $generator_backup ]] &&
    ! cmp -s "$feature_dir/omarchy-mise-install" "$generator"; then
  cp -a -- "$generator" "$generator_backup"
fi
generator_temporary=$(mktemp "$bin_home/.omarchy-mise-install.XXXXXX")
trap 'rm -f -- "$generator_temporary"' EXIT
install -m 755 "$feature_dir/omarchy-mise-install" "$generator_temporary"
mv -f -- "$generator_temporary" "$generator"
trap - EXIT

while IFS='|' read -r package command bin; do
  repair_wrapper "$package" "$command" "$bin"
done <<'SPECS'
codex|codex|codex
claude|claude|claude
crush|crush|crush
antigravity-cli|agy|agy
gh|gh|gh
copilot|copilot|copilot
gemini|gemini|gemini
opencode|opencode|opencode
npm:playwright|playwright|playwright
pi|pi|pi
github:can1357/oh-my-pi|omp|omp
npm:@xai-official/grok|grok|grok
npm:@kitlangton/ghui|ghui|ghui
aqua:modem-dev/hunk|hunk|hunk
github:basecamp/hey-cli|hey|hey
github:OpenRouterLabs/ori-releases|ori|ori
SPECS

printf '%s\n' 'Installed the temporary mise wrapper resolution fix.'
