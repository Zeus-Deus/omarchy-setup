#!/bin/bash
#
# AirPods audio+mic fix for Arch / Omarchy (April 2026+)
#
# Makes AirPods behave the way they do on macOS:
#   - Default profile is A2DP AAC (high-fidelity stereo playback).
#   - The mic is always visible to apps (Discord, Voxtype, browsers, OBS)
#     because WirePlumber 0.5.14 pre-creates a virtual loopback source.
#   - When an app actually opens the mic, the card auto-switches to HFP.
#     PipeWire negotiates Apple's LC3-24kHz codec if available, else mSBC.
#   - When the app releases the mic, the card auto-switches back to A2DP AAC.
#
# Also keeps the prior bluetooth-suspension fix, which prevents the
# left-ear-only / dropped-audio pathology after AirPods reconnect.
#
# Safe to rerun.  Idempotent.  Cleans up any prior version of this fix.

set -euo pipefail

WP_CONF_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
SUSPENSION_CONF="$WP_CONF_DIR/51-disable-bluetooth-suspension.conf"
CODEC_CONF="$WP_CONF_DIR/52-airpods-codec.conf"
OLD_SERVICE="$HOME/.config/systemd/user/airpods-headset-mode.service"

MIN_PIPEWIRE="1.5.81"
MIN_WIREPLUMBER="0.5.14"
MIN_BLUEZ="5.84"

log()  { printf '\033[1;36m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }
err()  { printf '\033[1;31m%s\033[0m\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# 1. Version check
# ---------------------------------------------------------------------------
log "Checking required packages..."

if ! command -v pacman >/dev/null 2>&1; then
  warn "  pacman not found; skipping version check. This script targets Arch/Omarchy."
else
  for pkg in pipewire wireplumber bluez libfdk-aac liblc3; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
      err "Missing package: $pkg"
      err "Install with: sudo pacman -S pipewire wireplumber bluez libfdk-aac liblc3"
      exit 1
    fi
  done

  check_version() {
    local pkg="$1" min="$2" cur
    cur=$(pacman -Q "$pkg" | awk '{print $2}' | sed 's/^[0-9]*://; s/-.*//')
    if ! printf '%s\n%s\n' "$min" "$cur" | sort -V -C; then
      err "$pkg $cur is older than required minimum $min"
      err "Update with: sudo pacman -Syu"
      exit 1
    fi
    printf '  %-12s %-10s  (>= %s)\n' "$pkg" "$cur" "$min"
  }

  check_version pipewire    "$MIN_PIPEWIRE"
  check_version wireplumber "$MIN_WIREPLUMBER"
  check_version bluez       "$MIN_BLUEZ"
fi

# ---------------------------------------------------------------------------
# 2. Remove older versions of this fix if present
# ---------------------------------------------------------------------------
if [ -f "$OLD_SERVICE" ] || systemctl --user list-unit-files airpods-headset-mode.service >/dev/null 2>&1; then
  log "Removing obsolete airpods-headset-mode daemon..."
  systemctl --user stop    airpods-headset-mode.service 2>/dev/null || true
  systemctl --user disable airpods-headset-mode.service 2>/dev/null || true
  rm -f "$OLD_SERVICE"
  systemctl --user daemon-reload
fi

# ---------------------------------------------------------------------------
# 3. WirePlumber config: keep Bluetooth nodes awake
# ---------------------------------------------------------------------------
log "Writing $SUSPENSION_CONF"
mkdir -p "$WP_CONF_DIR"
cat > "$SUSPENSION_CONF" <<'EOF'
# Keep Bluetooth nodes awake so AirPods reconnect cleanly without left-ear-only
# or dropped-audio artifacts.
monitor.bluez.rules = [
  {
    matches = [
      { node.name = "~bluez_output.*" }
      { node.name = "~bluez_input.*"  }
    ]
    actions = {
      update-props = {
        session.suspend-timeout-seconds = 0
      }
    }
  }
]
EOF

# ---------------------------------------------------------------------------
# 4. WirePlumber config: codec preferences + HFP autoswitch
# ---------------------------------------------------------------------------
log "Writing $CODEC_CONF"
cat > "$CODEC_CONF" <<'EOF'
# AirPods / Bluetooth headset codec preferences + automatic profile switching.
#
# Prefer Apple LC3-24kHz, then mSBC (16 kHz), then CVSD (8 kHz) for HFP mic.
# Use AAC VBR at max quality for A2DP playback, with SBC-XQ fallback.
# Enable HSP/HFP roles so WirePlumber pre-creates the always-on loopback
# source node that keeps the mic visible to apps while the card is in A2DP.
monitor.bluez.properties = {
  bluez5.enable-msbc               = true
  bluez5.enable-sbc-xq             = true
  bluez5.hfphsp-backend            = "native"
  bluez5.a2dp.aac.bitratemode      = 5
  bluez5.hfp-hf.default-mic-volume = 1.0
  bluez5.roles = [
    a2dp_sink  a2dp_source
    hfp_hf     hsp_hs
    hfp_ag     hsp_ag
    bap_sink   bap_source
  ]
}

# Always expose the Bluetooth mic; auto-switch to HFP only while an app is
# recording, then switch back to A2DP when the stream closes.
wireplumber.settings = {
  bluetooth.autoswitch-to-headset-profile = true
}
EOF

# ---------------------------------------------------------------------------
# 5. Restart WirePlumber and persist the live setting
# ---------------------------------------------------------------------------
log "Restarting WirePlumber..."
systemctl --user restart wireplumber

for _ in $(seq 1 30); do
  wpctl status >/dev/null 2>&1 && break
  sleep 1
done

wpctl settings --save bluetooth.autoswitch-to-headset-profile true >/dev/null

# ---------------------------------------------------------------------------
# 6. Summary
# ---------------------------------------------------------------------------
log ""
log "Done. AirPods now behave the macOS way:"
log "  - Default profile: A2DP AAC (high-fidelity stereo)"
log "  - Mic always visible to apps"
log "  - Auto-switch to HFP (LC3-24kHz or mSBC) while recording"
log "  - Auto-switch back to A2DP AAC when recording ends"
log ""
log "If your AirPods are already connected, reconnect them once so the new"
log "codec priority is re-negotiated. After reconnecting, verify the"
log "currently active codec with:"
log ""
log "    pactl list cards | grep -A1 -i airpods | grep -i 'Active Profile'"
log ""
log "The ideal profile to see is 'headset-head-unit' (LC3-24kHz). 'MSBC' is"
log "also fine. 'CVSD' means the LC3/mSBC handshake failed and mic quality"
log "will be noticeably worse - usually fixed by a fresh reconnect."
