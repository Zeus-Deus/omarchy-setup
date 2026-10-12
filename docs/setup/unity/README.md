# Unity on Omarchy

> Optional setup. This is not run by the main installer.

## Installation

Install Unity Hub from the AUR and the editor's compatibility library from Arch's Extra repository:

```bash
omarchy pkg aur add unityhub
omarchy pkg add libxml2-legacy
```

In Unity Hub, use **Installs** to download the editor version listed in the project's `ProjectSettings/ProjectVersion.txt`, then add and open the project from **Projects**. See the [official editor installation guide](https://docs.unity.com/en-us/hub/add-editor).

Hub and Editor are separate installations. The installed `unityhub` package's dependency list did not include `libxml2-legacy`; editors downloaded through Hub are outside pacman's dependency management.

## Project does not open

Unity Editor 6000.3.9f1 was observed failing before startup with:

```text
error while loading shared libraries: libxml2.so.2: cannot open shared object file: No such file or directory
```

[`libxml2-legacy`](https://archlinux.org/packages/extra/x86_64/libxml2-legacy/files/) provides `libxml2.so.2`. Installing it allowed this editor to start; the newer `libxml2` package alone did not satisfy that requirement. Keep the normal `libxml2` package installed.

To check another editor installation, substitute its version below:

```bash
ldd "$HOME/Unity/Hub/Editor/<version>/Editor/Unity" | rg 'not found'
```

No output means this check found no missing linked libraries. It does not verify every runtime dependency.

## Blank editor or tutorial dialog

On the first opening of a Mixed Reality template project with 6000.3.9f1, the editor and tutorial dialogs appeared blank even though the project had loaded. The editor log showed an initial Library rebuild and a loaded scene.

1. Allow the initial import to finish. Check `~/.config/unity3d/Editor.log` for progress if the window is blank.
2. If a blank **Close Tutorials** dialog is blocking the editor, focus that dialog and request a normal close with Omarchy's default **Super + W** shortcut. Apply the shortcut to the dialog, not the main editor window.
3. Return focus to the main Unity window and check whether the scene and panels draw normally.

In the observed session, sending a normal close request to **Close Tutorials** and refocusing the main editor restored the visible interface. The shortcut invokes the same close action. No additional package, renderer change, driver change, or Hyprland configuration change was needed.

This is an observed workaround, not a confirmed explanation of the blank windows. If it recurs, collect reproduction steps before changing graphics settings or reporting an Omarchy bug.

## Sharing diagnostics

Unity logs can contain access tokens, session or machine identifiers, network addresses, and personal project paths. Share only relevant, redacted excerpts; do not commit full logs or screenshots containing private information.
