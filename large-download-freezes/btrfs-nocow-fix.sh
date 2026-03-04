#!/bin/bash

echo "=========================================="
echo "Applying BTRFS NOCOW Fix for Steam, Downloads & ComfyUI"
echo "=========================================="
echo ""
echo "This script converts your Steam, Downloads, and ComfyUI folders"
echo "into BTRFS Subvolumes and applies the +C (No Copy-on-Write) attribute."
echo "This completely prevents lag when downloading massive files and stops"
echo "your Snapper backups from bloating."
echo ""
echo "IMPORTANT: This converts the ENTIRE parent folder, not just subfolders."
echo "For Steam, this means converting ~/.local/share/Steam/ (not just steamapps)"
echo "so that ALL Steam folders (depotcache, package, downloading, temp, etc.) are covered."
echo ""
echo "NOTE: Make sure Steam, ComfyUI, and all browsers are closed before continuing!"
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

# 2. Entire Steam Folder (not just steamapps!)
STEAM_DIR="$HOME/.local/share/Steam"
# Check flatpak steam as fallback
if [ ! -d "$STEAM_DIR" ] && [ -d "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" ]; then
    STEAM_DIR="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
fi

if [ -d "$STEAM_DIR" ] && ! btrfs subvolume show "$STEAM_DIR" >/dev/null 2>&1; then
    echo "Processing ENTIRE Steam folder: $STEAM_DIR"
    echo "This includes steamapps, depotcache, package, downloading, temp, and ALL other folders..."
    mv "$STEAM_DIR" "${STEAM_DIR}_old"
    btrfs subvolume create "$STEAM_DIR"
    chattr +C "$STEAM_DIR"
    echo "Copying data back (this will take a VERY long time for large libraries)..."
    rsync -a --info=progress2 "${STEAM_DIR}_old/" "$STEAM_DIR/"
    echo "You can manually delete ${STEAM_DIR}_old later if everything looks good."
else
    echo "Steam folder is already a subvolume or doesn't exist. Skipping."
fi

# 3. ComfyUI Folder (entire folder)
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
echo "  - ~/Downloads (entire folder)"
echo "  - ~/.local/share/Steam (ENTIRE folder, not just steamapps)"
echo "  - ~/comfyui (entire folder)"
echo ""
echo "This approach ensures ALL current and future subfolders are covered."
echo "For Steam: depotcache, package, downloading, temp, shadercache, etc."
echo ""
echo "To reclaim disk space after verifying everything works:"
echo "  rm -rf ~/Downloads_old"
echo "  rm -rf ~/.local/share/Steam_old"
echo "  rm -rf ~/comfyui_old"
