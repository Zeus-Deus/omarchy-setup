#!/usr/bin/env bash

set -euo pipefail

readonly repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly dotfiles_dir="$repo_dir/dotfiles/common"
readonly config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly bin_home="${HOME}/.local/bin"
readonly backup_suffix="bak.$(date +%Y%m%d%H%M%S)"

keyboard_profile="us"
display_profile=""
machine_profile=""

usage() {
  printf '%s\n' \
    "Usage: ${0##*/} [options]" \
    '' \
    'Options:' \
    '  --machine desktop|laptop  Install common and machine-specific packages' \
    '  --keyboard us|be-us       Select the keyboard layout profile (default: us)' \
    '  --display high-refresh    Apply a display profile (default: leave unchanged)' \
    '  -h, --help                Show this help'
}

while (( $# > 0 )); do
  case "$1" in
    --machine)
      (( $# >= 2 )) || {
        printf '%s\n' '--machine requires desktop or laptop.' >&2
        exit 2
      }
      machine_profile="$2"
      shift 2
      ;;
    --machine=*)
      machine_profile="${1#*=}"
      shift
      ;;
    --keyboard)
      (( $# >= 2 )) || {
        printf '%s\n' '--keyboard requires us or be-us.' >&2
        exit 2
      }
      keyboard_profile="$2"
      shift 2
      ;;
    --keyboard=*)
      keyboard_profile="${1#*=}"
      shift
      ;;
    --display)
      (( $# >= 2 )) || {
        printf '%s\n' '--display requires high-refresh.' >&2
        exit 2
      }
      display_profile="$2"
      shift 2
      ;;
    --display=*)
      display_profile="${1#*=}"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

readonly keyboard_profile
readonly keyboard_profile_source="$repo_dir/profiles/keyboards/$keyboard_profile"
readonly display_profile
readonly machine_profile
display_profile_source=""

[[ -f "$keyboard_profile_source" ]] || {
  printf 'Unknown keyboard profile: %s (choose us or be-us).\n' "$keyboard_profile" >&2
  exit 2
}

if [[ -n "$display_profile" ]]; then
  display_profile_source="$repo_dir/profiles/displays/$display_profile/monitors.lua"
  [[ -f "$display_profile_source" ]] || {
    printf 'Unknown display profile: %s (choose high-refresh).\n' "$display_profile" >&2
    exit 2
  }
fi
readonly display_profile_source

if [[ -n "$machine_profile" && ! -d "$repo_dir/profiles/packages/$machine_profile" ]]; then
  printf 'Unknown machine profile: %s (choose desktop or laptop).\n' "$machine_profile" >&2
  exit 2
fi

deploy() {
  local source="$1"
  local destination="$2"
  local mode="$3"

  if [[ -e "$destination" ]] && ! cmp -s "$source" "$destination"; then
    cp -a -- "$destination" "$destination.$backup_suffix"
  fi

  install -D -m "$mode" -- "$source" "$destination"
}

ensure_lua_require() {
  local config="$1"
  local module="$2"
  local anchor="$3"
  local require_line="require(\"$module\")"
  local temporary

  grep -Fxq "$require_line" "$config" && return

  temporary="$(mktemp)"
  if ! awk -v anchor="$anchor" -v require_line="$require_line" '
    { print }
    $0 == anchor { print require_line; inserted = 1 }
    END { if (!inserted) exit 1 }
  ' "$config" > "$temporary"; then
    rm -f -- "$temporary"
    printf 'Could not add %s to %s.\n' "$require_line" "$config" >&2
    exit 1
  fi

  cp -a -- "$config" "$config.$backup_suffix"
  install -m 644 -- "$temporary" "$config"
  rm -f -- "$temporary"
}

install_packages() {
  local profile="$1"
  local scope source package
  local -a repo_packages=()
  local -a aur_packages=()

  for scope in common "$profile"; do
    for source in repo aur; do
      [[ -f "$repo_dir/profiles/packages/$scope/$source" ]] || continue

      while IFS= read -r package || [[ -n "$package" ]]; do
        [[ -n "$package" && "$package" != \#* ]] || continue
        [[ "$package" =~ ^[a-zA-Z0-9@._+:-]+$ ]] || {
          printf 'Invalid package name in %s/%s: %s\n' "$scope" "$source" "$package" >&2
          exit 1
        }

        if [[ "$source" == repo ]]; then
          repo_packages+=("$package")
        else
          aur_packages+=("$package")
        fi
      done < "$repo_dir/profiles/packages/$scope/$source"
    done
  done

  (( ${#repo_packages[@]} == 0 )) || omarchy pkg add "${repo_packages[@]}"
  (( ${#aur_packages[@]} == 0 )) || omarchy pkg aur add "${aur_packages[@]}"
}

command -v omarchy >/dev/null 2>&1 || {
  printf 'Omarchy is required.\n' >&2
  exit 1
}

if [[ -n "$machine_profile" ]]; then
  install_packages "$machine_profile"
fi

readonly brave_profile_file="$dotfiles_dir/.config/omarchy-setup/browser-profile"
IFS= read -r brave_profile_name < "$brave_profile_file"
"$dotfiles_dir/.local/bin/brave-profile" "$brave_profile_name" --print-directory >/dev/null

deploy "$dotfiles_dir/.local/bin/brave-profile" "$bin_home/brave-profile" 755
deploy "$dotfiles_dir/.local/bin/xwayland-scale-wrapper" "$bin_home/xwayland-scale-wrapper" 755
deploy "$brave_profile_file" "$config_home/omarchy-setup/browser-profile" 644
deploy "$keyboard_profile_source" "$config_home/omarchy-setup/keyboard-profile" 644
deploy "$dotfiles_dir/.config/hypr/bindings.lua" "$config_home/hypr/bindings.lua" 644
deploy "$dotfiles_dir/.config/hypr/input.lua" "$config_home/hypr/input.lua" 644
deploy "$dotfiles_dir/.config/hypr/windows.lua" "$config_home/hypr/windows.lua" 644
if [[ -n "$display_profile_source" ]]; then
  deploy "$display_profile_source" "$config_home/hypr/monitors.lua" 644
fi

readonly hyprland_config="$config_home/hypr/hyprland.lua"
[[ -f "$hyprland_config" ]] || {
  printf 'Missing Hyprland config: %s\n' "$hyprland_config" >&2
  exit 1
}
ensure_lua_require "$hyprland_config" "hypr.windows" 'require("hypr.autostart")'

omarchy default browser brave

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  hyprctl reload
  if [[ -n "$(hyprctl configerrors)" ]]; then
    hyprctl configerrors >&2
    exit 1
  fi
fi

printf 'Omarchy setup installed. Machine: %s; Brave profile: %s; keyboard: %s; display: %s\n' \
  "${machine_profile:-not selected}" "$brave_profile_name" "$keyboard_profile" "${display_profile:-unchanged}"
