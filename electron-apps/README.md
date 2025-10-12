## Electron Apps: Hybrid GPU Fix (Fast Launch + Correct Scaling)

**Problem:** On hybrid GPU laptops (Intel iGPU + Nvidia dGPU), some Electron apps take 30-60 seconds to launch because they wake up the discrete GPU.

**Solution:** Force problematic apps to use XWayland instead of native Wayland.

### Setup

1. **Monitor configuration** - See [monitors configuration](https://github.com/Zeus-Deus/omarchy-setup/tree/main/monitors)

   - Ensure `GDK_SCALE` matches your monitor scale value

2. **Per-app flags** - Create `~/.config/APPNAME-flags.conf` for slow apps:
   --ozone-platform-hint=x11
   --force-device-scale-factor=1.25

Replace `1.25` with your monitor scale value.

### Known Slow Apps

- **Cursor**: `~/.config/cursor-flags.conf`
- **TickTick**: `~/.config/ticktick-flags.conf`

### Apps That Work Without Fixes

- VSCode (has native Wayland wrapper)
- Obsidian (has native Wayland wrapper)
- Brave browser (Chromium-based, no issue)

### Known Slow Apps

- **Cursor**: `~/.config/cursor-flags.conf`
- **TickTick**: `~/.config/ticktick/user-flags.conf` ⚠️ (different location!)
  TickTick is the outlier - most apps use ~/.config/appname-flags.conf, but TickTick uses ~/.config/ticktick/user-flags.conf instead.
