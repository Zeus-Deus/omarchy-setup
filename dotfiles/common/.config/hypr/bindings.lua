-- Personal Omarchy Quattro keybindings.
--
-- Omarchy's packaged defaults load first. Only personal additions and
-- explicit replacements belong in this user-owned file.

-- Replace Omarchy's browser bindings with the visible Brave profile "Me".
-- brave-profile resolves "Me" to Default, Profile 1, or whichever internal
-- directory Brave assigned on this computer.
hl.unbind("SUPER + SHIFT + B") -- Was: Browser
o.bind("SUPER + SHIFT + B", "Brave (default profile)", { launch = "brave-profile --default" })

hl.unbind("SUPER + SHIFT + ALT + B") -- Was: Browser (private)
o.bind("SUPER + SHIFT + ALT + B", "Brave private (default profile)", { launch = "brave-profile --default --incognito" })

-- Replace preinstalled web-app shortcuts with personal applications.
hl.unbind("SUPER + SHIFT + C") -- Was: Calendar
o.bind("SUPER + SHIFT + C", "TickTick", { launch = "ticktick" })

hl.unbind("SUPER + SHIFT + E") -- Was: Email
o.bind(
  "SUPER + SHIFT + E",
  "Proton Mail",
  { launch = 'brave-profile --default --webapp "https://mail.proton.me/"' }
)

-- Keep the web apps from the previous setup, pinned to the same Brave profile.
hl.unbind("SUPER + SHIFT + A") -- Was: ChatGPT
o.bind(
  "SUPER + SHIFT + A",
  "ChatGPT",
  { launch = 'brave-profile --default --webapp "https://chatgpt.com"' }
)

hl.unbind("SUPER + SHIFT + ALT + A") -- Was: Grok
o.bind(
  "SUPER + SHIFT + ALT + A",
  "Grok",
  { launch = 'brave-profile --default --webapp "https://grok.com"' }
)

hl.unbind("SUPER + SHIFT + Y") -- Was: YouTube
o.bind(
  "SUPER + SHIFT + Y",
  "YouTube",
  { launch = 'brave-profile --default --webapp "https://youtube.com/"' }
)

hl.unbind("SUPER + SHIFT + ALT + G") -- Was: WhatsApp
o.bind(
  "SUPER + SHIFT + ALT + G",
  "WhatsApp",
  { launch = 'brave-profile --default --focus-webapp "WhatsApp" "https://web.whatsapp.com/"' }
)

hl.unbind("SUPER + SHIFT + CTRL + G") -- Was: Google Messages
o.bind(
  "SUPER + SHIFT + CTRL + G",
  "Google Messages",
  { launch = 'brave-profile --default --focus-webapp "Google Messages" "https://messages.google.com/web/conversations"' }
)

-- X gets its own Brave instance (separate data dir, auto-created on first
-- launch; log in once) rendered without the GPU: on NVIDIA open drivers with a
-- 256 MiB BAR1 the aperture is already near full from other apps, and x.com's
-- autoplay feed tips it over and crashes Brave's Media thread. Software
-- rendering sidesteps BAR1 entirely. Normal Brave profiles are unaffected.
-- Open it as a regular browser: brave --user-data-dir="$HOME/.config/brave-x"
hl.unbind("SUPER + SHIFT + X") -- Was: X
o.bind(
  "SUPER + SHIFT + X",
  "X",
  { launch = 'omarchy-launch-webapp "https://x.com/" --user-data-dir="$HOME/.config/brave-x" --disable-gpu' }
)

hl.unbind("SUPER + SHIFT + ALT + X") -- Was: X Post
o.bind(
  "SUPER + SHIFT + ALT + X",
  "X Post",
  { launch = 'omarchy-launch-webapp "https://x.com/compose/post" --user-data-dir="$HOME/.config/brave-x" --disable-gpu' }
)

hl.unbind("SUPER + SHIFT + S") -- Was: Google Maps
o.bind(
  "SUPER + SHIFT + S",
  "Steam",
  { launch = "env -u SDL_VIDEODRIVER MANGOHUD=1 xwayland-scale-wrapper steam" }
)

-- Quattro uses this physical key for "Expand window down" by default.
hl.unbind("SUPER + SHIFT + code:21")
o.bind("SUPER + SHIFT + code:21", "Bitwarden", { launch = "bitwarden-desktop" })

-- Personal addition; this key is not occupied by Omarchy.
o.bind("SUPER + CTRL + ALT + X", "Voxtype config", { tui = "voxtype-tui", focus = true })

-- Universal copy/paste for T3 Code. Its embedded terminal treats Ctrl+V as a
-- literal ^V and Ctrl+C without a selection as an interrupt, while Omarchy
-- only switches to Ctrl+Shift+C/V for windows tagged "terminal". Ctrl+Insert /
-- Shift+Insert copy and paste in both T3's terminal and its text fields.
-- Other windows keep Omarchy's behavior (mirrors default/hypr/bindings/clipboard.lua).
do
  local function send_once(mods, key)
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end

  local function active_window_kind()
    local window = hl.get_active_window()
    if not window then return "default" end
    if window.class == "com.t3tools.T3Code" then return "t3" end
    for _, tag in ipairs(window.tags or {}) do
      if tag:gsub("%*$", "") == "terminal" then return "terminal" end
    end
    return "default"
  end

  local function clipboard_shortcut(key, insert_mods)
    return function()
      local kind = active_window_kind()
      if kind == "t3" then
        send_once(insert_mods, "Insert")
      elseif kind == "terminal" then
        send_once("CTRL SHIFT", key)
      else
        send_once("CTRL", key)
      end
    end
  end

  o.rebind("SUPER + C", "Universal copy", clipboard_shortcut("C", "CTRL"))
  -- Scripts (e.g. dictation) paste through o.universal_paste, so T3 gets this too.
  o.universal_paste = clipboard_shortcut("V", "SHIFT")
  o.rebind("SUPER + V", "Universal paste", o.universal_paste)
end
