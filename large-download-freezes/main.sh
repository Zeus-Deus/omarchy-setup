#!/bin/bash

# Fix: Small Periodic System Freezes During Downloads
# This script applies the dirty bytes fix to prevent system freezes during heavy disk I/O

set -e

CONFIG_FILE="/etc/sysctl.d/99-dirty-bytes.conf"

echo "=========================================="
echo "Fixing periodic system freezes during downloads"
echo "=========================================="
echo ""

# Check if file already exists
if [ -f "$CONFIG_FILE" ]; then
    echo "⚠️  Config file already exists: $CONFIG_FILE"
    echo "Current contents:"
    cat "$CONFIG_FILE"
    echo ""
    read -p "Overwrite? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Create the config file
echo "Creating config file: $CONFIG_FILE"
sudo tee "$CONFIG_FILE" > /dev/null << 'EOF'
# Fix small periodic system freezes during heavy disk I/O (e.g., downloads)
# Set dirty bytes to small enough value to prevent blocking writes
# 
# TO REVERT: Delete this file and reboot, or run: sudo sysctl -p
# 
# Previous defaults (for reference):
# vm.dirty_background_ratio = 10 (10% of RAM = ~6GB on 61GB system)
# vm.dirty_ratio = 20 (20% of RAM = ~12GB on 61GB system)

vm.dirty_background_bytes = 4194304
vm.dirty_bytes = 4194304
EOF

# Apply the settings immediately
echo "Applying settings..."
sudo sysctl -p "$CONFIG_FILE"

echo ""
echo "✅ Fix applied successfully!"
echo ""
echo "Current dirty page settings:"
sysctl vm.dirty_background_bytes vm.dirty_bytes vm.dirty_background_ratio vm.dirty_ratio
echo ""
echo "To revert, run: sudo rm $CONFIG_FILE && sudo sysctl -p"
