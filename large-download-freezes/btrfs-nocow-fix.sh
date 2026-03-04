#!/bin/bash

echo "=========================================="
echo "Applying BTRFS NOCOW Fix for Downloads & ComfyUI"
echo "=========================================="
echo ""
echo "This script converts your Downloads and ComfyUI folders"
echo "into BTRFS Subvolumes and applies NOCOW (+C) to stop lag."
echo ""
echo "NOTE: Make sure ComfyUI and all browsers are closed before continuing!"
read -p "Press Enter to continue..."

# 1. Downloads Folder (entire folder)
if [ -d "$HOME/Downloads" ] && ! btrfs subvolume show "$HOME/Downloads" >/dev/null 2>&1; then
    echo "Processing ~/Downloads..."
    mv "$HOME/Downloads" "$HOME/Downloads_old"
    btrfs subvolume create "$HOME/Downloads"
    chattr +C "$HOME/Downloads"
    echo "Copying data back (this may take a while)..."
    rsync -a --info=progress2 "$HOME/Downloads_old/" "$HOME/Downloads/"
    echo "You can manually delete ~/Downloads_old later if everything looks good."
else
    echo "~/Downloads is already a subvolume or doesn't exist. Skipping."
fi

# 2. ComfyUI Folder (entire folder)
if [ -d "$HOME/comfyui" ] && ! btrfs subvolume show "$HOME/comfyui" >/dev/null 2>&1; then
    echo "Processing ~/comfyui..."
    mv "$HOME/comfyui" "$HOME/comfyui_old"
    btrfs subvolume create "$HOME/comfyui"
    chattr +C "$HOME/comfyui"
    echo "Copying data back (this may take a while)..."
    rsync -a --info=progress2 "$HOME/comfyui_old/" "$HOME/comfyui/"
    echo "You can manually delete ~/comfyui_old later if everything looks good."
else
    echo "~/comfyui is already a subvolume or doesn't exist. Skipping."
fi

echo ""
echo "=========================================="
echo "✅ NOCOW Fix applied successfully!"
echo "=========================================="
echo ""
echo "What was converted:"
echo "  - ~/Downloads (entire folder with NOCOW)"
echo "  - ~/comfyui (entire folder with NOCOW)"
echo ""
echo "Note: The Steam directory is intentionally excluded from this script"
echo "because applying NOCOW to Steam tools or Proton prefixes causes"
echo "games to permanently fail with 'Exec format error'. See README"
echo "for instructions on how to safely use NOCOW with Steam games."
echo ""
echo "To reclaim disk space after verifying everything works:"
echo "  rm -rf ~/Downloads_old"
echo "  rm -rf ~/comfyui_old"
