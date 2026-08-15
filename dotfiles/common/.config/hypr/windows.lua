-- Keep the loaded Steam launcher tiled while preserving Omarchy's popup rules.
o.window({ class = "^steam$", title = "^Steam$" }, { tile = true })

-- Open Steam game windows in fullscreen.
o.window({ class = "^steam_app_.*$" }, { fullscreen = true })

-- Keep the RGBPC terminal UI in a centered utility window.
o.window({ initial_class = "^org\\.omarchy\\.RGBPC$" }, {
  float = true,
  center = true,
  size = { 800, 600 },
})

-- Keep personal terminal utilities compact instead of tiling them.
o.window({ initial_class = "^org\\.omarchy\\.Diskord$" }, {
  float = true,
  center = true,
  size = { 1000, 700 },
})

o.window({ initial_class = "^org\\.omarchy\\.voxtype-tui$" }, {
  float = true,
  center = true,
  size = { 1100, 750 },
})
