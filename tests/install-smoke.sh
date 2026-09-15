#!/usr/bin/env bash

set -euo pipefail

readonly fixture_home="/tmp/omarchy-home"
readonly fixture_bin="/tmp/omarchy-bin"
readonly config_home="$fixture_home/.config"
readonly command_log="/tmp/omarchy-command.log"
readonly xrdb_log="/tmp/xrdb-command.log"
readonly wrapped_command_log="/tmp/wrapped-command.log"

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
export OMARCHY_TEST_COMMAND_LOG="$command_log"
export XWAYLAND_TEST_XRDB_LOG="$xrdb_log"
export XWAYLAND_TEST_COMMAND_LOG="$wrapped_command_log"
export PATH="$fixture_bin:$PATH"

luac5.4 -p \
  /repo/dotfiles/common/.config/hypr/bindings.lua \
  /repo/dotfiles/common/.config/hypr/input.lua \
  /repo/dotfiles/common/.config/hypr/windows.lua \
  /repo/profiles/displays/high-refresh/monitors.lua

bash /repo/install.sh --keyboard us --display high-refresh

cmp /repo/dotfiles/common/.config/hypr/bindings.lua "$config_home/hypr/bindings.lua"
cmp /repo/dotfiles/common/.config/hypr/input.lua "$config_home/hypr/input.lua"
lua5.4 /repo/tests/input-settings.lua "$config_home/hypr/input.lua" us
cmp /repo/dotfiles/common/.config/hypr/windows.lua "$config_home/hypr/windows.lua"
cmp /repo/profiles/displays/high-refresh/monitors.lua "$config_home/hypr/monitors.lua"
cmp /repo/dotfiles/common/.local/bin/brave-profile "$fixture_home/.local/bin/brave-profile"
cmp /repo/dotfiles/common/.local/bin/xwayland-scale-wrapper "$fixture_home/.local/bin/xwayland-scale-wrapper"

[[ -x "$fixture_home/.local/bin/brave-profile" ]]
[[ -x "$fixture_home/.local/bin/xwayland-scale-wrapper" ]]
[[ "$(< "$config_home/omarchy-setup/keyboard-profile")" == "us" ]]
[[ "$(< "$config_home/omarchy-setup/browser-profile")" == "Me" ]]
[[ "$("$fixture_home/.local/bin/brave-profile" --default --print-directory)" == "Profile 1" ]]
[[ "$(grep -Fxc 'require("hypr.windows")' "$config_home/hypr/hyprland.lua")" -eq 1 ]]
grep -Fxq 'default browser brave' "$command_log"

: > "$command_log"
bash /repo/install.sh --machine desktop --keyboard us --display high-refresh
grep -Fxq 'pkg add bitwarden jq voxtype-bin mangohud openrgb steam xorg-xrdb' "$command_log"
grep -Fxq 'pkg aur add brave-bin diskord gazelle-tui ticktick voxtype-tui rgbpc' "$command_log"
grep -Fxq 'default browser brave' "$command_log"

: > "$command_log"
bash /repo/install.sh --machine laptop --keyboard us --display high-refresh
grep -Fxq 'pkg add bitwarden jq voxtype-bin asusctl rog-control-center' "$command_log"
grep -Fxq 'pkg aur add brave-bin diskord gazelle-tui ticktick voxtype-tui' "$command_log"
grep -Fxq 'default browser brave' "$command_log"

"$fixture_home/.local/bin/xwayland-scale-wrapper" wrapped-command first 'two words'
grep -Fxq 'Xft.dpi: 120.00' "$fixture_home/.Xresources"
grep -Fxq -- "-merge $fixture_home/.Xresources" "$xrdb_log"
grep -Fxq 'first two words' "$wrapped_command_log"

backup_count_before="$(find "$config_home" -type f -name '*.bak.*' | wc -l)"
bash /repo/install.sh --keyboard us --display high-refresh
backup_count_after="$(find "$config_home" -type f -name '*.bak.*' | wc -l)"
[[ "$backup_count_before" -eq "$backup_count_after" ]]
[[ "$(grep -Fxc 'require("hypr.windows")' "$config_home/hypr/hyprland.lua")" -eq 1 ]]

bash /repo/install.sh --keyboard be-us --display high-refresh
[[ "$(< "$config_home/omarchy-setup/keyboard-profile")" == "be-us" ]]
lua5.4 /repo/tests/input-settings.lua "$config_home/hypr/input.lua" be,us

printf '%s\n' '-- keep existing monitor settings --' > "$config_home/hypr/monitors.lua"
bash /repo/install.sh --machine laptop --keyboard be-us
grep -Fxq -- '-- keep existing monitor settings --' "$config_home/hypr/monitors.lua"

if bash /repo/install.sh --keyboard invalid >/dev/null 2>&1; then
  printf '%s\n' 'Expected an invalid keyboard profile to fail.' >&2
  exit 1
fi

if bash /repo/install.sh --machine invalid >/dev/null 2>&1; then
  printf '%s\n' 'Expected an invalid machine profile to fail.' >&2
  exit 1
fi

printf '%s\n' 'Container installer test passed.'
