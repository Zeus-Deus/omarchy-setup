#!/bin/bash

echo "=========================================="
echo "Applying BTRFS NOCOW Fix for Steam & Downloads"
echo "=========================================="
echo ""
echo "This script converts your Steam games folder and Downloads folder"
echo "into BTRFS Subvolumes and applies the +C (No Copy-on-Write) attribute."
echo "This completely prevents lag when downloading massive files and stops"
echo "your Snapper backups from bloating."
echo ""
echo "NOTE: Make sure Steam, ComfyUI, and all browsers are closed before continuing!"
read -p "Press Enter to continue..."

# 1. Downloads Folder
if [ -d "$HOME/Downloads" ] && ! btrfs subvolume show "$HOME/Downloads" >/dev/null 2>&1; then
    echo "Processing ~/Downloads..."
    mv "$HOME/Downloads" "$HOME/Downloads_old"
    btrfs subvolume create "$HOME/Downloads"
    chattr +C "$HOME/Downloads"
    echo "Copying data back (this may take a while)..."
    cp -a --reflink=never "$HOME/Downloads_old/." "$HOME/Downloads/"
    echo "You can manually delete ~/Downloads_old later if everything looks good."
else
    echo "~/Downloads is already a subvolume or doesn't exist. Skipping."
fi

# 2. Steam Folder
STEAM_DIR="$HOME/.local/share/Steam/steamapps"
# Check flatpak steam as fallback
if [ ! -d "$STEAM_DIR" ] && [ -d "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps" ]; then
    STEAM_DIR="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps"
fi

if [ -d "$STEAM_DIR" ] && ! btrfs subvolume show "$STEAM_DIR" >/dev/null 2>&1; then
    echo "Processing Steam folder..."
    mv "$STEAM_DIR" "${STEAM_DIR}_old"
    btrfs subvolume create "$STEAM_DIR"
    chattr +C "$STEAM_DIR"
    echo "Copying data back (this will take a VERY long time for large libraries)..."
    cp -a --reflink=never "${STEAM_DIR}_old/." "$STEAM_DIR/"
    echo "You can manually delete ${STEAM_DIR}_old later if everything looks good."
else
    echo "Steam folder is already a subvolume or doesn't exist. Skipping."
fi

echo ""
echo "✅ NOCOW Fix applied successfully!"

# 3. ComfyUI Folder
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
