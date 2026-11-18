# USB Headset: Noise When a Call and a Game Run Together

> Troubleshooting reference. Hardware placement only; nothing here changes the system.

## Problem

Wireless headset with separate Chat and Game outputs (SteelSeries Arctis 7).
With a voice call running, starting a game that plays on the Game output gave a
robotic sound, then a loud continuous tone, and the call went silent. Either one
alone was fine.

## Cause

The dongle was behind a USB hub. A call plus a game uses three streams at once
(chat out, mic in, game out), and that only failed through the hub.

"Plugged into the back of the PC" does not rule this out: some rear ports sit
behind a hub chip on the motherboard. On this board the blue rear ports did; a
red rear port is direct.

## Check

```bash
for d in /sys/bus/usb/devices/*-*; do [[ $d == *:* ]] || printf '%-8s %s\n' "${d##*/}" "$(cat "$d/product" 2>/dev/null)"; done
```

A name with a dot (`1-5.1`) is behind a hub; `3-2` is direct.

## Fix

Move the dongle to a port that shows up without a dot, then restart the game: a
game that was running during the replug has lost its audio stream.

## Notes

- Software cannot see this fault. The stream format, PipeWire error counters and
  USB frame rates all looked clean while the noise was audible, so trust what you
  hear over measurements.
- Muting the game's stream did not stop the tone; closing the game did.
- "Only one game does it" can simply mean it is the only app sent to the Game
  output; see [Proton game fixes](../../../features/proton-games/README.md).
- Keep the headset off your ears when retesting.
