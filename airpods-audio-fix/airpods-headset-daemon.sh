#!/bin/bash

set -euo pipefail

wait_for_audio_stack() {
  local retries=60

  while [ "$retries" -gt 0 ]; do
    if wpctl status >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
      return 0
    fi

    sleep 1
    retries=$((retries - 1))
  done

  echo "PipeWire/WirePlumber did not become ready in time."
  exit 1
}

find_airpods_card() {
  pactl list cards short | awk '/bluez_card/ { print $2; exit }'
}

find_airpods_sink() {
  pactl list sinks short | awk '/bluez_output/ { print $2; exit }'
}

find_airpods_source() {
  pactl list sources short | awk '/bluez_input/ { print $2; exit }'
}

apply_airpods_mode() {
  local card sink source

  card="$(find_airpods_card)"
  if [ -z "$card" ]; then
    return 0
  fi

  wpctl settings bluetooth.autoswitch-to-headset-profile false >/dev/null 2>&1 || true

  if ! pactl set-card-profile "$card" headset-head-unit 2>/dev/null; then
    pactl set-card-profile "$card" headset-head-unit-cvsd 2>/dev/null || true
  fi

  sleep 1

  sink="$(find_airpods_sink)"
  source="$(find_airpods_source)"

  if [ -n "$sink" ]; then
    pactl set-default-sink "$sink" || true
  fi

  if [ -n "$source" ]; then
    pactl set-default-source "$source" || true
    pactl set-source-volume "$source" 150% || true
  fi
}

wait_for_audio_stack

last_connected=0

if [ -n "$(find_airpods_card)" ]; then
  apply_airpods_mode
  last_connected=1
fi

while read -r _; do
  wait_for_audio_stack

  if [ -n "$(find_airpods_card)" ]; then
    if [ "$last_connected" -eq 0 ]; then
      apply_airpods_mode
    fi

    last_connected=1
  else
    last_connected=0
  fi
done < <(pactl subscribe)
