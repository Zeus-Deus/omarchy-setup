-- Run with the same environment as the installer smoke test.
local captured
hl = { config = function(settings) captured = settings.input end }
local source = assert(arg[1], "Expected input.lua path")
dofile(source)
assert(captured.touchpad.natural_scroll == true, "Touchpad natural scrolling must be enabled")
assert(captured.natural_scroll == nil, "Mouse scrolling must inherit its existing setting")
assert(captured.accel_profile == "flat", "Preserve pointer acceleration")
assert(captured.kb_layout == arg[2], "Preserve selected keyboard layout")
print("Input settings test passed: " .. captured.kb_layout)
