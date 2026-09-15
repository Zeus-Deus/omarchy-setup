-- Select the keyboard layout and shared pointer preferences here.
-- Unspecified input settings continue to inherit Omarchy's defaults.

local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local profile_path = config_home .. "/omarchy-setup/keyboard-profile"
local profile_file = assert(io.open(profile_path, "r"), "Missing keyboard profile: " .. profile_path)
local profile_name = profile_file:read("*l")
profile_file:close()

local profiles = {
  us = {
    kb_layout = "us",
    kb_variant = "",
    kb_options = "compose:caps,shift:both_capslock_cancel",
  },
  ["be-us"] = {
    kb_layout = "be,us",
    kb_variant = "",
    kb_options = "compose:caps,shift:both_capslock_cancel,grp:lalt_lshift_toggle,lv3:ralt_switch",
  },
}

local input_settings = assert(profiles[profile_name], "Unknown keyboard profile: " .. tostring(profile_name))

-- Keep mouse motion consistent for gaming instead of using libinput's
-- device-dependent adaptive acceleration.
input_settings.accel_profile = "flat"

-- Move content with your fingers on touchpads; leave mouse scrolling unchanged.
input_settings.touchpad = { natural_scroll = true }

hl.config({ input = input_settings })
