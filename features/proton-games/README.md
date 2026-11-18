# Proton game fixes (optional)

> Optional feature. Not run by the main installer: a game's Proton prefix only
> exists after its first launch.

Per-game fixes for Steam games on Proton, kept in the game's own prefix so the
desktop, other games, and Omarchy's defaults stay untouched.

A game with a saved output always plays there while that device is connected,
even if it is switched off. With the device unplugged, Wine falls back to the
desktop default output.

```bash
./proton-prefix.py apply            # apply everything in games.toml
./proton-prefix.py apply --dry-run  # report only
./proton-prefix.py show 311210      # current settings and known outputs
```

Requires Python 3.11+. Safe to rerun; a matching prefix is left unchanged.

## Symptoms and fixes

| Symptom | Cause | Fix |
|---|---|---|
| No game sound on a headset with separate Chat and Game outputs; everything else plays | The game opens the desktop default (mono Chat) and plays silence | `set APPID --output <game sink>` |
| Menus ignore the mouse until you switch workspace and back; breaks again after a click or a match | Wine grabs the pointer for a fullscreen window and the game stops tracking it | `set APPID --exe Game.exe --grab-pointer off` |
| Robotic noise, a loud tone, or silent call audio only while a call and the game run together | Headset dongle behind a USB hub | Hardware: see [USB headset noise](../../docs/troubleshooting/usb-headset-noise/README.md) |
| Game starts zoomed in | The game is saved as Windowed while a Hyprland rule forces it fullscreen | Set Fullscreen in the game's own settings; leaving fullscreen with `Super+F` makes the game save Windowed again |
| Infinite Warfare Zombies closes with "Content package is no longer available" | Steam installed Zombies without the Multiplayer component it depends on | Steam: Properties, DLC, tick "Call of Duty: Infinite Warfare - Multiplayer" (about 11 GB) |

None of these were Omarchy bugs. The first two are how Wine and the game
interact; the fixes are standard Wine settings.

## One game

```bash
./proton-prefix.py show APPID       # lists the sink names this prefix knows
./proton-prefix.py set APPID --output SINK
./proton-prefix.py set APPID --exe Game.exe --grab-pointer off
```

Undo with `--output default` or `--grab-pointer on`. Once a fix is confirmed in
play, add the game to `games.toml` so it can be restored after a reinstall.

## What the tool does

- Finds the prefix through Steam's library list and edits `pfx/user.reg`.
- Refuses to write while the game or its Proton session is running.
- Saves the previous registry to
  `~/.local/state/proton-prefix-tweaks/APPID/TIMESTAMP/user.reg` first.
- `--output` sets `HKCU\Software\Wine\Drivers\winepulse.drv\DefaultOutput` to the
  endpoint id of that sink. Each prefix generates its own ids, so the tool reads
  it from the prefix; an output the prefix has never seen is an error.
- `--grab-pointer off` sets
  `HKCU\Software\Wine\AppDefaults\Game.exe\X11 Driver\GrabPointer` to `N`.

## Things that did not work

- Moving the running game's stream to the Game output (`pactl move-sink-input`):
  the stream stayed mono and silent.
- A lower-case endpoint id: Wine compares case-sensitively and silently falls
  back to the default output.
- `UseTakeFocus=N` for the mouse: no effect.
- Changing the Hyprland fullscreen rule for the mouse: the bug happens with and
  without it.

## Checking a fix

- Audio: with the game playing, `pactl -f json list sink-inputs` should show the
  game's stream as 2 channels on the Game sink. Keep the headset off your ears
  for the first launch after an audio change.
- Mouse: on a fresh launch, without switching workspace, menu highlights should
  follow the pointer before and after a click, after entering and leaving a
  submenu, and after a match. Aiming must still turn past a screen width.

## Tests

```bash
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -m unittest discover -s tests -p 'test_proton_prefix*.py'
```
