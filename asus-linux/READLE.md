# ASUS ROG Linux Setup Guide (Omarchy/Arch)

Quick setup guide for ASUS ROG laptops on Arch-based distributions, specifically tested on **Omarchy**.

## What This Does

Installs and configures ASUS-specific tools for ROG laptops:

- **asusctl**: Control fan profiles, keyboard RGB/LEDs, battery charge limits, performance modes
- **ROG Control Center**: GUI for managing ASUS features
- **NVIDIA Power Management**: Optimizes GPU power states for better battery life and proper suspend/resume

## Requirements

- Arch-based Linux distribution (this guide is for **Omarchy**)
- ASUS ROG laptop with NVIDIA GPU
- Working NVIDIA drivers (Omarchy auto-installs these during setup if it detects NVIDIA hardware)

## Why This Works on Omarchy

**Omarchy already handles several things automatically:**

- **NVIDIA drivers are pre-installed** if your laptop has an NVIDIA GPU (no manual driver installation needed)
- **Limine bootloader** is pre-configured (guide's bootloader section not needed)
- **Base system is already set up** (skip installation section entirely)

**This guide only adds ASUS-specific hardware control** - everything else is already configured by Omarchy.

## What's NOT Included

- **NVIDIA driver installation**: Skip entirely - Omarchy already did this
- **Bootloader configuration**: Skip entirely - Limine is already set up
- **supergfxctl**: Deprecated, not recommended by official guide
- **linux-g14 kernel**: Optional custom kernel for advanced fan curves (install later if needed)
- **Secure boot**: Optional security feature (configure separately if needed)

## Installation

Follow the commands in the guide step-by-step. After completing all steps, reboot.

## Source

Based on official ASUS Linux guide: https://asus-linux.org/guides/arch-guide/

## Post-Install

Launch "ROG Control Center" from application menu to access all ASUS-specific features.

## Notes

- Services like nvidia-suspend/resume show as "inactive" when not actively suspending - this is normal
- nvidia-powerd should show as "active (running)" after reboot
- If nvidia.conf.pacnew warning appears, use the diff/replace commands shown in guide
- Omarchy uses standard Arch repositories, so all packages install normally via pacman
