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

hl.unbind("SUPER + SHIFT + X") -- Was: X
o.bind(
  "SUPER + SHIFT + X",
  "X",
  { launch = 'brave-profile --default --webapp "https://x.com/"' }
)

hl.unbind("SUPER + SHIFT + ALT + X") -- Was: X Post
o.bind(
  "SUPER + SHIFT + ALT + X",
  "X Post",
  { launch = 'brave-profile --default --webapp "https://x.com/compose/post"' }
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
