#!/usr/bin/env bash

set -euo pipefail

# Runs anywhere: the repo is located from this script, fixtures live in a
# throwaway directory, and the live Hyprland session (if any) is ignored.
readonly repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly fixture_root="$(mktemp -d)"
trap 'rm -rf -- "$fixture_root"' EXIT
unset HYPRLAND_INSTANCE_SIGNATURE

readonly fixture_home="$fixture_root/home"
readonly fixture_bin="$fixture_root/bin"
readonly config_home="$fixture_home/.config"
readonly command_log="$fixture_root/omarchy-command.log"
readonly xrdb_log="$fixture_root/xrdb-command.log"
readonly wrapped_command_log="$fixture_root/wrapped-command.log"

install -d \
  "$fixture_bin" \
  "$config_home/BraveSoftware/Brave-Browser" \
  "$config_home/hypr"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\\n" "$*" >> "$OMARCHY_TEST_COMMAND_LOG"' \
  > "$fixture_bin/omarchy"
chmod 755 "$fixture_bin/omarchy"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'exit 0' \
  > "$fixture_bin/brave"
chmod 755 "$fixture_bin/brave"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\\n" '\''[{"focused":false,"scale":1},{"focused":true,"scale":1.25}]'\''' \
  > "$fixture_bin/hyprctl"
chmod 755 "$fixture_bin/hyprctl"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\\n" "$*" > "$XWAYLAND_TEST_XRDB_LOG"' \
  > "$fixture_bin/xrdb"
chmod 755 "$fixture_bin/xrdb"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\\n" "$*" > "$XWAYLAND_TEST_COMMAND_LOG"' \
  > "$fixture_bin/wrapped-command"
chmod 755 "$fixture_bin/wrapped-command"

printf '%s\n' \
  '{"profile":{"info_cache":{"Profile 1":{"name":"Me"},"Default":{"name":"Secondary"}}}}' \
  > "$config_home/BraveSoftware/Brave-Browser/Local State"

printf '%s\n' \
  'require("omarchy")' \
  'require("hypr.autostart")' \
  > "$config_home/hypr/hyprland.lua"

export HOME="$fixture_home"
export XDG_CONFIG_HOME="$config_home"
export XDG_STATE_HOME="$fixture_home/.local/state"
export XDG_DATA_HOME="$fixture_home/.local/share"
export XDG_CACHE_HOME="$fixture_home/.cache"
export XDG_RUNTIME_DIR="$fixture_home/run"
export OMARCHY_TEST_COMMAND_LOG="$command_log"
export XWAYLAND_TEST_XRDB_LOG="$xrdb_log"
export XWAYLAND_TEST_COMMAND_LOG="$wrapped_command_log"
export PATH="$fixture_bin:$PATH"

luac5.4 -p \
  "$repo_dir"/dotfiles/common/.config/hypr/bindings.lua \
  "$repo_dir"/dotfiles/common/.config/hypr/input.lua \
  "$repo_dir"/dotfiles/common/.config/hypr/windows.lua \
  "$repo_dir"/profiles/displays/high-refresh/monitors.lua

bash "$repo_dir"/install.sh --keyboard us --display high-refresh

cmp "$repo_dir"/dotfiles/common/.config/hypr/bindings.lua "$config_home/hypr/bindings.lua"
cmp "$repo_dir"/dotfiles/common/.config/hypr/input.lua "$config_home/hypr/input.lua"
cmp "$repo_dir"/dotfiles/common/.config/hypr/windows.lua "$config_home/hypr/windows.lua"
cmp "$repo_dir"/profiles/displays/high-refresh/monitors.lua "$config_home/hypr/monitors.lua"
cmp "$repo_dir"/dotfiles/common/.local/bin/brave-profile "$fixture_home/.local/bin/brave-profile"
cmp "$repo_dir"/dotfiles/common/.local/bin/xwayland-scale-wrapper "$fixture_home/.local/bin/xwayland-scale-wrapper"
cmp "$repo_dir"/dotfiles/common/.local/share/applications/X.desktop "$fixture_home/.local/share/applications/X.desktop"

[[ -x "$fixture_home/.local/bin/brave-profile" ]]
[[ -x "$fixture_home/.local/bin/xwayland-scale-wrapper" ]]
[[ "$(< "$config_home/omarchy-setup/keyboard-profile")" == "us" ]]
[[ "$(< "$config_home/omarchy-setup/browser-profile")" == "Me" ]]
[[ "$("$fixture_home/.local/bin/brave-profile" --default --print-directory)" == "Profile 1" ]]
[[ "$(grep -Fxc 'require("hypr.windows")' "$config_home/hypr/hyprland.lua")" -eq 1 ]]
grep -Fxq 'default browser brave' "$command_log"
grep -Fxq 'setup security sudoless docker' "$command_log"

: > "$command_log"
bash "$repo_dir"/install.sh --machine desktop --keyboard us --display high-refresh
grep -Fxq 'pkg add bitwarden jq voxtype-bin mangohud openrgb steam xorg-xrdb' "$command_log"
grep -Fxq 'pkg aur add brave-bin diskord gazelle-tui ticktick voxtype-tui rgbpc' "$command_log"
grep -Fxq 'default browser brave' "$command_log"

: > "$command_log"
bash "$repo_dir"/install.sh --machine laptop --keyboard us --display high-refresh
grep -Fxq 'pkg add bitwarden jq voxtype-bin asusctl rog-control-center' "$command_log"
grep -Fxq 'pkg aur add brave-bin diskord gazelle-tui ticktick voxtype-tui' "$command_log"
grep -Fxq 'default browser brave' "$command_log"

"$fixture_home/.local/bin/xwayland-scale-wrapper" wrapped-command first 'two words'
grep -Fxq 'Xft.dpi: 120.00' "$fixture_home/.Xresources"
grep -Fxq -- "-merge $fixture_home/.Xresources" "$xrdb_log"
grep -Fxq 'first two words' "$wrapped_command_log"

backup_count_before="$(find "$config_home" -type f -name '*.bak.*' | wc -l)"
bash "$repo_dir"/install.sh --keyboard us --display high-refresh
backup_count_after="$(find "$config_home" -type f -name '*.bak.*' | wc -l)"
[[ "$backup_count_before" -eq "$backup_count_after" ]]
[[ "$(grep -Fxc 'require("hypr.windows")' "$config_home/hypr/hyprland.lua")" -eq 1 ]]

bash "$repo_dir"/install.sh --keyboard be-us --display high-refresh
[[ "$(< "$config_home/omarchy-setup/keyboard-profile")" == "be-us" ]]

printf '%s\n' '-- keep existing monitor settings --' > "$config_home/hypr/monitors.lua"
bash "$repo_dir"/install.sh --machine laptop --keyboard be-us
grep -Fxq -- '-- keep existing monitor settings --' "$config_home/hypr/monitors.lua"

if bash "$repo_dir"/install.sh --keyboard invalid >/dev/null 2>&1; then
  printf '%s\n' 'Expected an invalid keyboard profile to fail.' >&2
  exit 1
fi

if bash "$repo_dir"/install.sh --machine invalid >/dev/null 2>&1; then
  printf '%s\n' 'Expected an invalid machine profile to fail.' >&2
  exit 1
fi

# The feature stays opt-in, then installs through the main entry point.
[[ ! -e "$fixture_home/.local/share/mise-wrapper-guard/guard.py" ]]
bash "$repo_dir"/install.sh --mise-wrapper-resolution
grep -Fq 'hook install post-update ' "$command_log"
[[ -f "$fixture_home/.local/share/mise-wrapper-guard/guard.py" ]]
[[ ! -e "$fixture_home/.local/bin/omarchy-mise-install" ]]

# herdr overrides merge into the existing config and are opt-in.
printf '%s\n' '#!/usr/bin/env bash' '[[ $1 == config ]]' > "$fixture_bin/herdr"
chmod 755 "$fixture_bin/herdr"
install -d "$config_home/herdr"
printf '%s\n' '[ui]' 'accent = "blue"' > "$config_home/herdr/config.toml"
bash "$repo_dir"/install.sh
if grep -q sidebar_max_width "$config_home/herdr/config.toml"; then
  printf '%s\n' 'herdr overrides applied without --herdr.' >&2
  exit 1
fi
bash "$repo_dir"/install.sh --herdr
grep -Fq 'hook install post-update ' "$command_log"
grep -Fxq 'accent = "blue"' "$config_home/herdr/config.toml"
grep -Fxq 'sidebar_max_width = 60  # omarchy-setup' "$config_home/herdr/config.toml"
herdr_config_before="$(cat "$config_home/herdr/config.toml")"
bash "$repo_dir"/install.sh --herdr
[[ "$(cat "$config_home/herdr/config.toml")" == "$herdr_config_before" ]]

printf '%s\n' 'Container installer test passed.'
