#!/bin/bash

# Define the configuration directory
CONFIG_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
CONFIG_FILE="$CONFIG_DIR/51-disable-bluetooth-suspension.conf"

echo "Applying AirPods / Bluetooth Audio Fixes..."

# 1. Disable "Auto-switch to headset profile"
# This prevents WirePlumber from switching to the low-quality HSP/HFP profile
# when a microphone is requested, keeping it on high-quality A2DP.
echo "-> Disabling Bluetooth auto-switch to headset profile..."
wpctl settings --save bluetooth.autoswitch-to-headset-profile false

# 2. Disable Bluetooth audio node suspension
# This prevents the audio stream from "sleeping" after 5 seconds of silence,
# which causes the AirPods to lose sync (left ear only) or drop audio entirely.
echo "-> Creating WirePlumber configuration to disable Bluetooth suspension..."

# Ensure the user configuration directory exists
mkdir -p "$CONFIG_DIR"

# Write the configuration snippet
cat > "$CONFIG_FILE" << 'EOF'
monitor.bluez.rules = [
  {
    matches = [
      {
        # Matches all bluetooth sinks (outputs)
        node.name = "~bluez_output.*"
      }
    ]
    actions = {
      update-props = {
        session.suspend-timeout-seconds = 0
      }
    }
  }
]
EOF

echo "-> Restarting PipeWire and WirePlumber services..."
systemctl --user restart pipewire wireplumber

echo ""
echo "Fix applied successfully! Your AirPods should now maintain connection and audio quality."
echo "Note: If you are currently connected, you may need to disconnect and reconnect them once."
