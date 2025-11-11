Here is the **wrapper script** that dynamically detects your Hyprland Wayland monitor scale, calculates DPI, updates Xresources, and launches an XWayland app (e.g., Steam) with the correct scaling.

---

### Wrapper script: `~/.local/bin/xwayland-scale-wrapper`

```bash
#!/bin/bash

# Get monitor scale from Hyprland
SCALE=$(hyprctl monitors | grep "scale:" | head -1 | awk '{print $2}')

# Calculate DPI assuming base DPI 96
DPI=$(echo "96 * $SCALE" | bc)

# Write DPI value to Xresources
echo "Xft.dpi: $DPI" > ~/.Xresources

# Load Xresources DPI values for XWayland/X11 apps
xrdb -merge ~/.Xresources

# Launch the application passed as arguments
exec "$@"
```

Remember to make it executable:

```bash
chmod +x ~/.local/bin/xwayland-scale-wrapper
```

---

### How to use:

To launch Steam (or any XWayland app) with this wrapper and correct DPI scaling:

```bash
xwayland-scale-wrapper steam
```

---

### Adding to Steam shortcut for automatic scaling:

1. Copy Steam desktop entry locally:

```bash
cp /usr/share/applications/steam.desktop ~/.local/share/applications/steam.desktop
```

2. Edit the file:

```bash
nvim ~/.local/share/applications/steam.desktop
```

3. Find the `Exec=` line and change it from:

```
Exec=/usr/bin/steam %U
```

to:

```
Exec=xwayland-scale-wrapper /usr/bin/steam %U
```

4. Save and exit.

---

This will ensure Steam always launches with DPI matching your Hyprland scale.
