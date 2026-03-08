# Apple AirPods Always-On Audio + Mic Fix

This directory contains the setup I use on Omarchy to make AirPods work like a regular always-available Bluetooth headset.

The goal is simple:

- keep the Bluetooth connection stable
- keep the AirPods microphone visible to apps
- keep audio playback and mic working without needing extra mode-switch commands

## The problem this fixes

On this setup, AirPods had two separate issues:

1. Bluetooth playback could wake up badly after silence, causing left-ear-only playback or dropped audio.
2. The microphone was only available when PipeWire switched the AirPods into headset mode, which meant some apps could fail to detect the mic at all.

## The default fix

Run this once:

```bash
./fix-airpods.sh
```

That does all of the following:

- disables Bluetooth output suspension so the earlier AirPods sync and reconnect issue stays fixed
- saves `bluetooth.autoswitch-to-headset-profile=false`
- installs and enables a user service that puts the AirPods back into headset mode whenever they connect
- sets the AirPods as the default Bluetooth sink and source when they are connected
- raises the AirPods headset mic gain to `150%`, because the raw mic level is very quiet on this setup

The result is:

- AirPods stay in audio + mic mode by default
- apps like Discord can detect the mic more reliably because it already exists
- the earlier Bluetooth stability fix is still preserved

## Why this mode is the default

Classic Bluetooth normally has a tradeoff:

- `A2DP` = better music quality, usually no normal mic source
- `HFP/HSP` = audio + mic together, but lower playback quality

For this setup, the default priority is to make AirPods just work without thinking about profile switching.

So this fix keeps the AirPods in headset mode by default.

If you temporarily want the best playback quality, you can still change the AirPods profile manually in Omarchy's audio Configuration tab. That manual change is temporary. After the AirPods reconnect, the default headset behavior will return.

## What gets installed

The setup script writes this WirePlumber override:

- `~/.config/wireplumber/wireplumber.conf.d/51-disable-bluetooth-suspension.conf`

It also installs this user service:

- `~/.config/systemd/user/airpods-headset-mode.service`

That service runs the helper script in this repo:

- `airpods-audio-fix/airpods-headset-daemon.sh`

The helper watches for AirPods reconnects and reapplies headset mode only when the AirPods connect again, so it does not keep fighting you every second while they are already connected.

## Safe to rerun

`./fix-airpods.sh` is safe to run again.

It always rewrites the same config file and the same user service file, then reloads and restarts the same user service.

## Verifying it worked

After running the fix, reconnect the AirPods once if they are already connected.

You should then see the AirPods behave like this:

- the microphone is already present in apps instead of only appearing after profile switching
- the AirPods show headset mode in the audio Configuration view
- audio playback and mic both work at the same time

## Quick reference

- `./fix-airpods.sh` - the only setup command you need for this AirPods fix
