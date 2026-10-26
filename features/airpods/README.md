# AirPods Audio + Mic Fix (Linux / Arch / Omarchy)

> Optional feature. This is not run by the main installer.
>
> **Separate capture bug:** these settings do not fix the PipeWire Bluetooth
> transport failure seen when opening the mic during playback. The official
> `1:1.6.10-1` package still failed the October 26, 2026 test. Keep the working
> user-local plugin until a verified official replacement passes. See the
> [temporary PipeWire patch, rebuild recipe, and retirement procedure](pipewire-bluetooth-patch.md).

A one-shot setup that makes AirPods behave the way they do on macOS:

- **High-fidelity stereo (A2DP AAC) by default.**
- **Microphone is always visible to apps** - Discord, Voxtype, browsers, OBS - even while A2DP is active.
- **Automatic profile switch to HFP when recording**, with Apple's LC3-24kHz voice codec if negotiated, else mSBC (16 kHz).
- **Automatic switch back to A2DP AAC when recording ends**, so music quality comes straight back.

No manual profile switching. No permanent audio quality hit. No broken microphone in Discord.

## Run it

```bash
./fix-airpods.sh
```

That's the whole setup. Safe to rerun.

## Prerequisites

The script checks for these automatically:

- `pipewire` >= 1.5.81  (adds Apple's LC3-24kHz HFP codec)
- `wireplumber` >= 0.5.14  (always-on virtual mic loopback)
- `bluez` >= 5.84
- `libfdk-aac` (AAC A2DP playback)
- `liblc3` (LC3 HFP voice codec)

On Arch / Omarchy these are all in the stock `pipewire` / `wireplumber` package set and will already be installed by default.

## What gets installed

Two WirePlumber drop-ins in `~/.config/wireplumber/wireplumber.conf.d/`:

- `51-disable-bluetooth-suspension.conf` - keeps Bluetooth nodes awake so reconnects don't produce left-ear-only or stutter.
- `52-airpods-codec.conf` - codec preferences (LC3 > mSBC > CVSD for HFP, AAC VBR for A2DP) and `bluetooth.autoswitch-to-headset-profile = true`.

And one `wpctl` setting is persisted:

- `bluetooth.autoswitch-to-headset-profile = true`

The script also removes any older `airpods-headset-mode.service` systemd user unit if it finds one (from earlier versions of this fix that forced HSP/HFP always on).

## Why this approach

Classic Bluetooth only offers two modes:

- **A2DP**: stereo, music-grade, *no mic*.
- **HFP/HSP**: mono, low-quality, *has mic*.

There is no standardized way to get simultaneous high-quality stereo + mic over classic Bluetooth, and AirPods do not implement LE Audio / LC3-BAP, so the "just use LE Audio" path doesn't work for them. macOS and Windows do the exact same A2DP-to-HFP switch - they just hide it better.

PipeWire 1.5.81 (Oct 2025) added Apple's proprietary **LC3-24kHz** codec for HFP, which is the same codec an iPhone uses. WirePlumber 0.5.14 (Feb 2026) added an **always-on virtual loopback source** so the mic shows up in every app's picker while the card stays in A2DP, and flips to HFP only when an app actually opens the stream. That combination is what this fix relies on.

## Verify after running

```bash
# Inspect the AirPods card's Active Profile and codec descriptions:
pactl list cards
```

Inspect the codec **description** in `pactl list cards`; profile names vary by
headset and negotiated codecs. On the AirPods tested on October 26, 2026,
`headset-head-unit` means **mSBC**, not LC3. `headset-head-unit-cvsd` is narrowband
CVSD; `a2dp-sink` is the AAC playback profile. Do not force a lower-quality codec
as a substitute for the [capture patch](pipewire-bluetooth-patch.md).

## Known caveats

- **First ~200-1000 ms of speech may be clipped** when an app opens the mic, because the BlueZ A2DP-to-HFP SCO handshake takes that long. macOS has the same limit - it just feels less jarring there. For push-to-talk apps (Voxtype etc.), pre-opening the mic a fraction of a second before speech helps.
- **Some apps cache the device list at startup.** If Discord doesn't see the AirPods mic, restart Discord after connecting. Firefox, Chromium, native apps, and Vesktop all re-enumerate correctly; Zoom is the worst offender.
- **HFP voice is always lower quality than A2DP music.** That's a Bluetooth Classic limit, not a Linux bug. LC3-24kHz is close to macOS quality; mSBC is clearly worse; CVSD is unusable.
- **If your BT adapter is Realtek**, mSBC may silently fall back to CVSD. Intel AX210/AX211 and MediaTek MT7922/MT7925 are reliable. Check with `dmesg | grep -i voice_setting` - `0x0003` means mSBC-ready.

## Mic too quiet?

Bump the software source volume once per session:

```bash
wpctl set-volume $(wpctl status | awk '/Sources/,/Filters/{if($0 ~ /AirPods|bluez_input/) print $2}' | tr -d '.') 1.5
```

Or open `pavucontrol` -> Input Devices -> AirPods and drag the slider.

## Rollback

Restore the prior setup in one block:

```bash
rm ~/.config/wireplumber/wireplumber.conf.d/52-airpods-codec.conf
wpctl settings --save bluetooth.autoswitch-to-headset-profile false
systemctl --user restart wireplumber
```

(The `51-disable-bluetooth-suspension.conf` drop-in is independently useful and safe to keep.)
