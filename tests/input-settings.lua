-- Run with the same environment as the installer smoke test.
local captured
local devices = {}
hl = {
  config = function(settings) captured = settings.input end,
  device = function(settings) devices[#devices + 1] = settings end,
}
local source = assert(arg[1], "Expected input.lua path")
dofile(source)
assert(captured.touchpad.natural_scroll == true, "Touchpad natural scrolling must be enabled")
assert(captured.natural_scroll == nil, "Mouse scrolling must inherit its existing setting")
assert(captured.accel_profile == "flat", "Preserve pointer acceleration")
assert(captured.kb_layout == arg[2], "Preserve selected keyboard layout")
assert(captured.sensitivity == nil, "Do not change global pointer sensitivity")
assert(captured.touchpad.scroll_factor == nil, "Preserve default touchpad scroll speed")
assert(#devices == 1, "Override only the laptop touchpad")
assert(devices[1].name == "asue120d:00-04f3:31fb-touchpad", "Target only the laptop touchpad model")
assert(devices[1].sensitivity == 0.2, "Use the tested touchpad sensitivity")
for key in pairs(devices[1]) do
  assert(key == "name" or key == "sensitivity", "Do not override unrelated device settings")
end
print("Input settings test passed: " .. captured.kb_layout)
