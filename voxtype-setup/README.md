# Voxtype Setup - Voice-to-Text Dictation

## Overview

Voxtype is a push-to-talk voice-to-text tool that works with Omarchy's built-in dictation feature. This guide covers installation and setup when the Omarchy repo version is broken.

## Installation

### Problem

The Omarchy Package Repository version of `voxtype-bin` may be broken (404 error). Install from AUR instead.

### Solution

```bash
# Install from AUR using explicit source
yay -S aur/voxtype-bin
```

If that doesn't work, use the [force-aur-install](../force-aur-install/README.md) method.

## Setup Steps

### 1. Add User to Input Group

Required for keyboard simulation (typing the transcribed text).

```bash
sudo usermod -aG input $USER
```

**Note:** You may need to log out and back in for this to take effect.

### 2. Download Whisper Model

Download the AI model for transcription (default is ~150MB base English model).

```bash
voxtype setup --download
```

### 3. Start Voxtype Service

Enable and start the voxtype daemon.

```bash
systemctl --user enable --now voxtype
```

### 4. Verify Installation

Check that the service is running.

```bash
voxtype status
# Should show: idle
```

## Usage

### Basic Usage

1. Open any text field (terminal, browser, editor, etc.)
2. Hold `Super + Ctrl + X` to start dictating
3. Release the keys to stop and insert transcribed text
4. A red mic icon appears in the top menu while dictating

### Quick Commands

```bash
# Check status
voxtype status

# View configuration
voxtype config

# Check system setup
voxtype setup check
```

## Optional Configuration

### Switch Models

Download different Whisper models (better accuracy, larger files).

```bash
voxtype setup model
```

### Enable GPU Acceleration

Faster transcription using your GPU (requires Vulkan).

```bash
sudo voxtype setup gpu --enable
```

### Edit Configuration

```bash
# View config
voxtype config

# Edit manually
# ~/.config/voxtype/config.toml
```

### Waybar Integration

Get Waybar status integration.

```bash
voxtype setup waybar
```

## Troubleshooting

### Shortcut Not Working

1. Verify service is running: `voxtype status`
2. Log out and back in (for input group to take effect)
3. Check keybinding in `~/.config/hypr/bindings.conf`

### Microphone Not Detected

```bash
# Check audio setup
voxtype setup check

# Test microphone
# Use your system audio settings to verify mic is working
```

### Service Not Starting

```bash
# Check service status
systemctl --user status voxtype

# View logs
journalctl --user -u voxtype -f
```

## Files and Locations

- **Config:** `~/.config/voxtype/config.toml`
- **Models:** `~/.local/share/voxtype/models/`
- **Service:** `~/.config/systemd/user/voxtype.service`
