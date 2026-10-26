# Temporary PipeWire Bluetooth capture patch

Optional, manual maintenance procedure; **not run by `install.sh` or
`fix-airpods.sh`**. Keep normal package updates enabled. Do not pin PipeWire,
replace package-owned files, or copy a compiled plugin between machines.

## Status and reason

Opening the AirPods microphone while A2DP playback is active can collapse the
Bluetooth transport, leaving Voxtype with short, silent input. This was reproduced
with the official PipeWire **`1:1.6.10-1`** package and WirePlumber **0.5.18** on
October 26, 2026. It is not a transcription-model failure; this test does not
establish that the bug is exclusive to AirPods.

Matched capture tests used active playback before every take, automatic AAC
A2DP → mSBC HFP switching, 16-kHz mono s16 input, three-second takes and four-second
gaps. A pass required at least two seconds of capture with nonzero samples.

| Plugin | Usable captures |
|---|---:|
| Patched 1.6.9, before trial | 10/10 |
| Official `1:1.6.10-1` | 1/10 |
| Same patch, after rollback | 10/10 |

The nine failed official takes contained only about 0.02–0.60 seconds of silence;
the journal recorded Bluetooth transport and node errors. The exact official
plugin was verified through WirePlumber's process mappings. These are microphone
capture tests, **not** full dictation or hotkey tests. Raw recordings and machine
identifiers are deliberately not stored in this repository.

**Keep the override until BOTH the packaged source contains the fixes and a
controlled official-plugin trial passes. A higher version number is not proof.**

## Exact upstream changes

The working baseline is PipeWire tag `1.6.9`, commit
`8fa27cabdc6c0c1350c69c026af5850ef0af1e26`, plus these upstream commits:

- `b7246d0d5ddc79cbab06e7e55f6dda37c446118d` —
  `bluez5: deal with asynchronous device and node removal` (MR !3004).
- `d80b80602b389fe9badeda830122d357e9e2e3ea` —
  `bluez5: reset the transport error count on a successful acquire` (MR !2997).

The exact `1.6.10` tag lacks both changes. When checking a future release, inspect
the code, not just commit ancestry: backports may have different commit IDs.
Look for the transport `remove_node` events/handlers and resetting
`transport->error_count` after a successful acquire.

## Rebuild without replacing system packages

This is a recovery recipe for the tested 1.6.x baseline, not an instruction to
load a 1.6.9 plugin into an arbitrary future PipeWire version. Reassess API/ABI and
runtime dependencies before reuse; stop if the build or validation fails.

Build prerequisites on Arch include Git, a C/C++ toolchain, Meson, Ninja,
pkgconf, `dbus`, `bluez-libs`, `glib2-devel`, and `sbc`, alongside the normal
PipeWire audio/codec packages. `glib2-devel` supplies `gdbus-codegen`; having
`glib2` alone is insufficient. Install missing prerequisites through the normal
package-management flow. If using `uv`, `uvx meson` can replace `meson` below.

Run in Bash, keeping the same shell for the preparation block that follows:

```bash
set -euo pipefail
mkdir -p "${TMPDIR:-$HOME/.cache}"
build_root=$(mktemp -d "${TMPDIR:-$HOME/.cache}/pipewire-bluez5.XXXXXX")
git clone --depth 1 --branch 1.6.9 \
  https://github.com/PipeWire/pipewire.git "$build_root/source"
cd "$build_root/source"
test "$(git rev-parse HEAD)" = 8fa27cabdc6c0c1350c69c026af5850ef0af1e26
# Depth 2 is intentional: cherry-pick needs each patch commit's parent.
git fetch --depth 2 origin \
  b7246d0d5ddc79cbab06e7e55f6dda37c446118d \
  d80b80602b389fe9badeda830122d357e9e2e3ea
git -c user.name='Local patch build' -c user.email='local@localhost' cherry-pick \
  b7246d0d5ddc79cbab06e7e55f6dda37c446118d \
  d80b80602b389fe9badeda830122d357e9e2e3ea
meson setup build --prefix=/usr -Dauto_features=disabled \
  -Dspa-plugins=enabled -Dbluez5=enabled -Ddbus=enabled \
  '-Dsession-managers=[]' -Dexamples=disabled -Dtests=disabled \
  -Dman=disabled -Ddocs=disabled
ninja -C build spa/plugins/bluez5/libspa-bluez5.so
ldd build/spa/plugins/bluez5/libspa-bluez5.so
```

Do not proceed if `ldd` reports a missing dependency. On October 26, this source
checkout, patch application, and library build were exercised successfully in an
isolated workspace; the rebuilt library was **not** substituted for the working
live plugin.

## Prepare a user-local override

First inspect `systemctl --user cat pipewire wireplumber`. Stop and reconcile any
existing `SPA_PLUGIN_DIR` override rather than stacking or overwriting it. If the
following paths already exist, keep them and use the retest procedure instead.

This block deliberately refuses to overwrite existing patch paths. It mirrors
installed SPA plugins, retaining the distro's separate codec libraries, and
replaces only `libspa-bluez5.so`. It writes user-owned files but does not restart
audio. Keep the build output and this document with your local rollback notes.

```bash
patch_root="$HOME/.local/lib/pipewire-bluez5-test"
plugin="$build_root/source/build/spa/plugins/bluez5/libspa-bluez5.so"
test -s "$plugin"
test ! -e "$patch_root" && test ! -L "$patch_root"
for unit in pipewire wireplumber; do
  conf="$HOME/.config/systemd/user/$unit.service.d/99-bluez5-fix-test.conf"
  test ! -e "$conf" && test ! -L "$conf"
done
mkdir -p "$patch_root/spa-0.2/bluez5"
for entry in /usr/lib/spa-0.2/*; do
  test "$(basename "$entry")" = bluez5 && continue
  ln -s "$entry" "$patch_root/spa-0.2/"
done
for entry in /usr/lib/spa-0.2/bluez5/*; do
  test "$(basename "$entry")" = libspa-bluez5.so && continue
  ln -s "$entry" "$patch_root/spa-0.2/bluez5/"
done
install -m 755 "$plugin" "$patch_root/spa-0.2/bluez5/libspa-bluez5.so"
for unit in pipewire wireplumber; do
  conf="$HOME/.config/systemd/user/$unit.service.d/99-bluez5-fix-test.conf"
  mkdir -p "$(dirname "$conf")"
  printf '[Service]\nEnvironment="SPA_PLUGIN_DIR=%s/spa-0.2"\n' \
    "$patch_root" > "$conf"
done
```

Activate only after agreeing to a brief audio interruption:
`systemctl --user daemon-reload`, then
`systemctl --user restart pipewire pipewire-pulse wireplumber`.
Check all three services and Voxtype are active, the headset has returned, and
default input/output routing is correct. Verify the loaded library:

```bash
pid=$(systemctl --user show wireplumber -p MainPID --value)
grep 'libspa-bluez5.so' "/proc/$pid/maps"
```

Mappings must reference the user-local `pipewire-bluez5-test` path. Rerun the
capture test below before considering the recovery complete. The recipe does
not install or alter Voxtype itself.

## Retest a future official package safely

1. Check exact installed versions with `pacman -Q pipewire pipewire-audio
   libpipewire wireplumber`, verify package integrity with `pacman -Qkk`, and
   confirm the candidate source includes both fixes. Do not unpatch solely
   because an update is available.
2. With the headset connected, record a patched baseline under the failing
   condition: playback actively routed to the headset before **every** mic-open,
   then capture from the default source. Verify the actual headset/codec, not
   just a profile-name suffix. Use at least ten three-second takes with
   four-second gaps, measuring duration and nonzero samples. Delete temporary
   mic recordings after collecting metrics.
3. Save exact drop-ins, plugin, default routing, persisted HFP preference, and
   prior Voxtype service state. Agree to audio interruption. Temporarily stop
   Voxtype; rename **only these two patch drop-ins** out of the `.conf` suffix,
   leaving the library and backups intact. Reload systemd and restart audio.
   Use guaranteed cleanup/rollback on failure or interruption; do not run an
   unattended one-way removal command.
4. Check process mappings now point to
   `/usr/lib/spa-0.2/bluez5/libspa-bluez5.so`, restore the intended routing, and
   repeat the identical loop. No playback, wrong microphone, or lost connection
   makes the test inconclusive, not a pass. Inspect the audio-service journal.
5. On **any failure or inconclusive result**, restore both drop-ins, reload and
   restart audio, restore routing and Voxtype's previous state, verify the
   patched mapping, and repeat the passing capture loop.
6. Only after an official pass, also check idle capture and actual spoken
   Voxtype dictation. Leave the official plugin active only if those pass.
   Archive the fallback before removing it; record the passing package version
   and date here, and retire the reminder. Never lower mic quality just to make
   a candidate pass.

## Candidate reminder

The daily 10:00 reminder is a **profile-local Hermes job**, not part of this
repo's installer. Recreating it is a separate opt-in step; the audio fix does
not depend on Hermes. Its contract is:

- Compare full Arch versions using `vercmp`; `1:1.6.10-1` is the tested-bad build.
- Stay quiet for that build and older builds. Notify once per newer candidate
  and installed/available state, using a desktop notification.
- Say **"candidate to retest; keep the working patch"**, never "safe to remove".
- Never install updates, alter codecs, restart services, or remove the override.
- Record successful delivery for deduplication; surface notification failures.

A version watch only discovers candidates. Source verification and the
controlled capture/dictation trial remain the removal gate.
