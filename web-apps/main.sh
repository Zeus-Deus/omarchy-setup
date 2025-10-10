# if you have multiple Brave profiles you need to choose one for default use

# Step 1: Choose Your Profile

ls ~/.config/BraveSoftware/Brave-Browser

for dir in ~/.config/BraveSoftware/Brave-Browser/*/; do
  echo "Directory: $(basename "$dir")"
  cat "$dir/Preferences" 2>/dev/null | jq -r '.profile.name' 2>/dev/null || echo "No name found"
  echo ""
done

# my default profile is called "Me"

# Step 2: Copy the System Desktop File
# Copy the system Brave desktop file to create a custom version:
cp /usr/share/applications/brave-browser.desktop ~/.local/share/applications/brave-custom.desktop

# Step 3: Edit the Custom Desktop File
# Open the file for editing:
nvim ~/.local/share/applications/brave-custom.desktop
# Find the line that starts with Exec=brave (usually near the top) and modify it to include the profile directory:
# For the Default profile ("Me"):
Exec=brave --profile-directory="Default" %U
# Or for Profile 1 ("Person 1"):
Exec=brave --profile-directory="Profile 1" %U
# Save and exit.

# Step 4: Set as Default Browser
# Set the custom desktop file as the system default:
xdg-settings set default-web-browser brave-custom.desktop
# Now all Omarchy web apps and the Super + B shortcut will launch Brave 
# with the specified profile automatically, without showing the profile picker.

# THE ABOVE MADE THE DEFAULT BROWSER BRAVE BUT DID NOT CORRECTLY OPEN PROFILES, IT SHOWED THE PROFILE MENU EACH START UP

# Open the bindings file:
nvim ~/.config/hypr/bindings.conf

# Find this line:
# $browser = omarchy-launch-browser
# Replace it with (choose one based on which profile):
# For "Default" profile ("Me"):
$browser = uwsm app -- brave --profile-directory="Default" --new-window --ozone-platform=wayland

# Reload Hyprland:
hyprctl reload

# my shortcut web-apps were stilll opening in chromium even though the Super + B did open the correct Brave profile
# ran this and found out multiple exec commands:
# cat ~/.local/share/applications/brave-custom.desktop | grep Exec
# output was:
# TryExec=brave
# Exec=brave --profile-directory="Default" %U
# Exec=brave
# Exec=brave --incognito

# Fix the Desktop File
# Delete the broken file and recreate it properly:
rm ~/.local/share/applications/brave-custom.desktop

# Now create a new proper one:
nvim ~/.local/share/applications/brave-custom.desktop

# Paste this exact content (single Exec line only):
[Desktop Entry]
Version=1.0
Name=Brave Web Browser
Comment=Access the Internet
Exec=brave --profile-directory="Default" %U
StartupNotify=true
Terminal=false
Icon=brave-browser
Type=Application
Categories=Network;WebBrowser;
MimeType=x-scheme-handler/unknown;x-scheme-handler/about;x-scheme-handler/https;x-scheme-handler/http;text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/webcal;x-scheme-handler/chrome;video/webm;application/x-xpinstall;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Exec=brave --profile-directory="Default"

[Desktop Action new-private-window]
Name=New Private Window
Exec=brave --profile-directory="Default" --incognito
# Save and exit

# Update Default Browser Again
xdg-settings set default-web-browser brave-custom.desktop

# Test It

# DOING THIS ALSO DID NOT CHANGE THE SHORTCUT WEB-APP's TO WORK

# found out this script needed to be edited:
cat ~/.local/share/omarchy/bin/omarchy-launch-webapp

# The script is checking for brave-browser* but the custom desktop file is named brave-custom.desktop. 
# It doesn't match the pattern, so it falls back to chromium.desktop.

# Solution: Rename the Desktop File
mv ~/.local/share/applications/brave-custom.desktop ~/.local/share/applications/brave-browser-custom.desktop

# Update xdg-settings:
xdg-settings set default-web-browser brave-browser-custom.desktop
