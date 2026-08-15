-- Keep Omarchy's scale variables so the Quickshell display panel can continue
-- to persist scale changes. Prefer the highest advertised refresh rate.

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "highrr", position = "auto", scale = omarchy_monitor_scale })
