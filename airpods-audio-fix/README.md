# Apple AirPods Bluetooth Audio Fix

This directory contains a fix for common issues encountered when using Apple AirPods (or similar Bluetooth headsets) on Linux with PipeWire/WirePlumber.

## The Issues

1. **Left Ear Only / Dropping Audio on New Video:**
   PipeWire has a power-saving feature called "node suspension." When no audio plays for 5 seconds (like pausing a video or switching tabs), PipeWire puts the audio connection to sleep. AirPods have a complex left/right sync mechanism, and when PipeWire tries to instantly wake the connection, the earbuds fail to sync fast enough. This results in only the left ear waking up, or the audio stream completely failing to play.

2. **Weird / Degraded Audio Quality:**
   WirePlumber is configured by default to automatically switch to the "Headset Profile" (HSP/HFP) when a microphone is requested or upon reconnection. HSP/HFP is designed for phone calls and sounds muffled compared to the high-fidelity A2DP profile used for music/videos.

## The Solution

The provided `fix-airpods.sh` script applies two fixes:

1. **Disables Auto-Switch to Headset Profile:**
   Using `wpctl`, it disables the setting that automatically switches Bluetooth devices to the low-quality HSP/HFP profile. Since a dedicated gaming headset USB dongle is used for the microphone, this is safe to disable, forcing the AirPods to remain in high-quality A2DP mode.

2. **Disables Bluetooth Audio Suspension:**
   It creates a WirePlumber configuration override file (`~/.config/wireplumber/wireplumber.conf.d/51-disable-bluetooth-suspension.conf`) to set `session.suspend-timeout-seconds = 0` exclusively for Bluetooth outputs. This keeps the connection "awake" even during silence, preventing sync issues when audio resumes.

## Usage

Simply run the fix script:

```bash
./fix-airpods.sh
```

If your AirPods are currently connected, disconnect and reconnect them once to ensure the new configuration takes effect.

## Will this affect my USB Headset Dongle?

No. The suspension override is specifically targeted at devices matching `~bluez_output.*` (Bluetooth devices only). Your USB headset (ALSA/USB Audio) will continue to function normally.
