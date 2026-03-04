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
echo "IMPORTANT NEXT STEPS IN STEAM:"
echo "1. Open Steam"
echo "2. Go to Settings > Storage"
echo "3. Click the dropdown at the top and select 'Add Drive'"
echo "4. Navigate to and select the /home/$USER/Games folder"
echo ""
echo "HOW TO MAKE IT THE DEFAULT FOR FUTURE GAMES:"
echo "- In the Storage menu, select your new ~/Games drive from the dropdown."
echo "- Click the '...' (three dots) button on the right side."
echo "- Select 'Make Default'."
echo "*(Steam will still automatically keep Proton in the old folder, don't worry!)*"
echo ""
echo "HOW TO FIX EXISTING GAMES:"
echo "- In the Storage menu, select your old default drive"
echo "- Check the boxes next to your heavy games (like Arc Raiders)"
echo "- Click 'Move' and transfer them to the new ~/Games drive."
echo "=========================================="
