#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HELPER_SCRIPT="$SCRIPT_DIR/airpods-headset-daemon.sh"
CONFIG_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
CONFIG_FILE="$CONFIG_DIR/51-disable-bluetooth-suspension.conf"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_DIR/airpods-headset-mode.service"

wait_for_wpctl() {
  local retries=60

  while [ "$retries" -gt 0 ]; do
    if wpctl status >/dev/null 2>&1; then
      return 0
    fi

    sleep 1
    retries=$((retries - 1))
  done

  echo "WirePlumber did not become ready in time."
  exit 1
}

echo "Applying AirPods always-on headset fix..."
echo "- Keep the Bluetooth connection awake to avoid AirPods sync/drop issues"
echo "- Keep AirPods in audio + mic mode so apps can always detect the mic"

wait_for_wpctl

mkdir -p "$CONFIG_DIR"
mkdir -p "$SYSTEMD_DIR"
chmod +x "$HELPER_SCRIPT"

cat > "$CONFIG_FILE" <<'EOF'
monitor.bluez.rules = [
  {
    matches = [
      {
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

echo "-> Saving Bluetooth setting to keep headset auto-switch disabled..."
wpctl settings bluetooth.autoswitch-to-headset-profile false
wpctl settings --save bluetooth.autoswitch-to-headset-profile false

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Keep AirPods in headset mode
After=pipewire.service pipewire-pulse.service wireplumber.service
Wants=pipewire.service pipewire-pulse.service wireplumber.service

[Service]
Type=simple
ExecStart=$HELPER_SCRIPT
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF

echo "-> Enabling AirPods headset helper service..."
systemctl --user daemon-reload
systemctl --user enable --now airpods-headset-mode.service
systemctl --user restart airpods-headset-mode.service

sleep 2

echo
echo "Done. Your AirPods are now configured for always-detected audio + mic."
echo "- Bluetooth suspension fix stays enabled"
echo "- AirPods reconnect into headset mode after login/reconnect"
echo "- AirPods mic gain is raised because the headset mic is very quiet by default"
echo
echo "If you temporarily want best playback quality instead, you can still change the profile manually in the audio Configuration tab."
echo "The default behavior will return after reconnecting the AirPods or restarting the user service."
