---

### SDL_VIDEODRIVER Unset for Steam on Omarchy

By default, Omarchy sets the environment variable:

```
SDL_VIDEODRIVER=wayland
```

This causes Steam and Proton games to fail launching or have compatibility issues because Steam expects to use XWayland (X11), not pure Wayland, as its video backend.

---

### Fix

Launch Steam with the `SDL_VIDEODRIVER` environment variable **unset** to force fallback to XWayland:

```bash
env -u SDL_VIDEODRIVER steam
```

---

### Why

- Omarchy enables `SDL_VIDEODRIVER=wayland` by default globally.
- SDL tries to use Wayland backend exclusively, which Steam does not fully support yet.
- Unsetting it allows SDL and Steam to use XWayland backend, fixing game launch and UI issues on Omarchy.

---

### Note

You can make this permanent by editing your Steam launch options or desktop entry to always launch with this command.

---
