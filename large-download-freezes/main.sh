#!/bin/bash

echo "====================================================="
echo "   Omarchy: Large Download Freezes Master Fix"
echo "====================================================="
echo "This master script will run all 3 recommended fixes to stop"
echo "system lag and freezes during massive downloads."
echo ""
echo "The following scripts will be executed in order:"
echo " 1. sysctl-dirty-bytes-fix.sh   (RAM cache fix)"
echo " 2. btrfs-nocow-fix.sh          (Downloads/ComfyUI fix)"
echo " 3. btrfs-nocow-steam-games.sh  (Steam NOCOW library fix)"
echo ""
echo "If you prefer, you can cancel (Ctrl+C) and run them individually."
echo "====================================================="
read -p "Press Enter to start running all fixes..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "-----------------------------------------------------"
echo "Running [1/3]: sysctl-dirty-bytes-fix.sh"
echo "-----------------------------------------------------"
if [ -f "$SCRIPT_DIR/sysctl-dirty-bytes-fix.sh" ]; then
    bash "$SCRIPT_DIR/sysctl-dirty-bytes-fix.sh"
else
    echo "⚠️ Error: sysctl-dirty-bytes-fix.sh not found!"
fi

echo ""
echo "-----------------------------------------------------"
echo "Running [2/3]: btrfs-nocow-fix.sh"
echo "-----------------------------------------------------"
if [ -f "$SCRIPT_DIR/btrfs-nocow-fix.sh" ]; then
    bash "$SCRIPT_DIR/btrfs-nocow-fix.sh"
else
    echo "⚠️ Error: btrfs-nocow-fix.sh not found!"
fi

echo ""
echo "-----------------------------------------------------"
echo "Running [3/3]: btrfs-nocow-steam-games.sh"
echo "-----------------------------------------------------"
if [ -f "$SCRIPT_DIR/btrfs-nocow-steam-games.sh" ]; then
    bash "$SCRIPT_DIR/btrfs-nocow-steam-games.sh"
else
    echo "⚠️ Error: btrfs-nocow-steam-games.sh not found!"
fi

echo ""
echo "====================================================="
echo "🎉 All selected fixes have been executed!"
echo "====================================================="
