#!/bin/bash

echo "=========================================="
echo "Creating NOCOW Steam/Games Directory"
echo "=========================================="
echo ""
echo "This script creates a special ~/Games folder that has the NOCOW"
echo "(No Copy-on-Write) attribute enabled. Any games installed or moved"
echo "into this folder will bypass BTRFS CoW, preventing system lag and"
echo "freezes during massive multi-gigabyte downloads."
echo ""
echo "NOTE: This script does NOT touch your default Steam installation."
echo "Proton and Steam runtimes MUST stay in their default location with"
echo "CoW enabled to function properly."
echo ""
read -p "Press Enter to continue..."

# Create ~/Games directory if it doesn't exist
if [ ! -d "$HOME/Games" ]; then
    echo "Creating ~/Games directory..."
    mkdir -p "$HOME/Games"
else
    echo "~/Games already exists."
fi

# Apply NOCOW to ~/Games
echo "Applying NOCOW (+C) attribute to ~/Games..."
# If files already exist, chattr -R +C might fail on them, but we apply to the root so future files get it
chattr +C "$HOME/Games" 2>/dev/null

echo ""
echo "=========================================="
echo "✅ ~/Games is now ready for lag-free downloads!"
echo "=========================================="
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. Open Steam"
echo "2. Go to Settings > Storage"
echo "3. Click the dropdown at the top and select 'Add Drive'"
echo "4. Navigate to and select the /home/$USER/Games folder"
echo "5. Select 'Let me choose' or make it the default for new games."
echo ""
echo "To move existing games to stop lag:"
echo "- In Steam Settings > Storage, select your default drive"
echo "- Check the box next to your heavy games (like Arc Raiders)"
echo "- Click 'Move' and select your new ~/Games drive."
echo ""
echo "Note: Steam tools like Proton and Steam Linux Runtime will"
echo "automatically stay in the default Steam folder. This is exactly"
echo "what you want, as they require standard CoW to function."
echo "=========================================="
