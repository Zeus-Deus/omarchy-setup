# The Ultimate Steam Setup on Omarchy (Hyprland)

Getting Steam to work flawlessly on Omarchy (Arch + Hyprland) requires a few coordinated fixes. By default, you might face issues like invisible windows, games crashing, or blurry XWayland scaling.

This guide combines three critical components for the perfect setup:
1.  **Launch Command Fixes** (Env vars & XWayland scaling)
2.  **Window Rules** (Fixing transparency & tiling)
3.  **Bindings** (Quick launch shortcuts)

---

### 1. The Launch Command (Fixing Crashes & Scaling)

By default, Omarchy sets `SDL_VIDEODRIVER=wayland`, which breaks many Proton games and Steam itself. We must unset this. We also use a custom wrapper to fix XWayland scaling issues.

**The Fix:**
Always launch Steam using this command chain:
```bash
env -u SDL_VIDEODRIVER MANGOHUD=1 ~/.local/bin/xwayland-scale-wrapper steam
```

*   `env -u SDL_VIDEODRIVER`: Forces Steam to use XWayland (required for stability).
*   `MANGOHUD=1`: Enables the FPS overlay (optional).
*   `xwayland-scale-wrapper`: A script that handles HiDPI scaling for legacy apps.

> **Get the wrapper script here:** [xwayland-auto-scale](../xwayland-auto-scale)

---

### 2. Window Rules (Fixing Invisible Windows & Tiling)

Steam on Hyprland v0.53+ is tricky. Without these rules, the main window might be invisible, or popups (Friends/Settings) might get stretched into tiles.

**Add these to your `windows.conf`:**
(See the full file in [windows/](../windows))

```ini
# --- Steam Fixes ---

# 1. Force Main Steam Window to TILE
# We use 'float 0' and 'tile 1' to force tiling.
windowrule = float 0, match:class ^(steam)$, match:title ^(Steam)$
windowrule = tile 1, match:class ^(steam)$, match:title ^(Steam)$

# 2. Ensure popups float (Friends, Settings, etc.)
windowrule = float 1, match:class ^(steam)$, match:title ^(Friends List|Settings|Properties)$

# --- Game Fixes (Excluding Steam) ---

# 1. Force Opacity (Fixes transparent/ghostly games)
windowrule = opacity 1.0 override 1.0 override, match:xwayland 1

# 2. Force Fullscreen (Hides Waybar) for Games
windowrule = fullscreen 1, match:xwayland 1, match:class negative:^(steam)$
```

---

### 3. Key Bindings

Tie it all together with a robust shortcut. This ensures every time you launch Steam, it uses the correct environment variables and wrappers.

**Add this to your `bindings.conf`:**
(See the full file in [keyboard-shortcut/](../keyboard-shortcut))

```ini
bindd = SUPER SHIFT, S, Steam, exec, env -u SDL_VIDEODRIVER MANGOHUD=1 ~/.local/bin/xwayland-scale-wrapper steam
```

---

### Summary Checklist

1.  ✅ Install the [xwayland-scale-wrapper](../xwayland-auto-scale).
2.  ✅ Apply the [Window Rules](../windows) to `~/.config/hypr/windows.conf`.
3.  ✅ Add the [Binding](../keyboard-shortcut) to `~/.config/hypr/bindings.conf`.
