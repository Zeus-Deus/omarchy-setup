**Here's your complete guide for switching Omarchy from iwd to NetworkManager with full 802.1X support:**

---

## Omarchy: Switch from iwd to NetworkManager for 802.1X WiFi (eduroam)

### Why This Is Needed

Omarchy uses iwd by default, which doesn't support WPA2 Enterprise (802.1X) authentication needed for school WiFi and eduroam. This guide switches to NetworkManager with wpa_supplicant—the same setup KDE uses.

---

### Step 1: Install NetworkManager and Required Packages

```bash
# Install NetworkManager, wpa_supplicant backend, and GUI tools
sudo pacman -S networkmanager wpa_supplicant network-manager-applet nm-connection-editor
```

**What this does**: Installs the NetworkManager daemon, wpa_supplicant for 802.1X support, nm-applet for system tray, and nm-connection-editor for advanced configuration.

---

### Step 2: Disable iwd and systemd-networkd

```bash
# Stop current networking services
sudo systemctl stop iwd systemd-networkd

# Disable them from auto-starting
sudo systemctl disable iwd systemd-networkd
```

**What this does**: Stops iwd and systemd-networkd so they don't conflict with NetworkManager.

---

### Step 3: Enable and Start NetworkManager

```bash
# Enable NetworkManager to start on boot
sudo systemctl enable NetworkManager

# Start NetworkManager now
sudo systemctl start NetworkManager
```

**What this does**: Makes NetworkManager your primary network manager and starts it immediately.

---

### Step 4: Reboot

```bash
sudo reboot
```

**What this does**: Cleans up driver conflicts and ensures everything starts fresh without iwd interference.

---

### Step 5: Configure Waybar to Use nm-applet

After reboot, edit `~/.config/waybar/config.jsonc`:

```bash
nano ~/.config/waybar/config.jsonc
```

Find the `"network"` section and change:

```jsonc
"on-click": "omarchy-launch-wifi"
```

To:

```jsonc
"on-click": "nm-applet --indicator"
```

**What this does**: Makes the waybar WiFi icon launch nm-applet instead of Impala.

---

### Step 6: Reload Waybar

```bash
killall waybar
waybar &
```

**What this does**: Restarts waybar to apply the new configuration.

---

### Step 7: Connect to Regular WiFi

Click the nm-applet icon in the waybar tray (click the tray expander arrow if needed) → select WiFi → enter password.

Note: nm-applet auto-starts from /etc/xdg/autostart/ and appears in the system tray by default.

---

### Step 8: Connect to 802.1X WiFi (eduroam at school)

**Option A: If nm-applet prompts for username/password automatically**

- Click your school WiFi → enter username and password → connect

**Option B: If it only asks for password (manual configuration needed)**

1. Open nm-connection-editor: `Super + Space` → search "nm-connection-editor"
2. Click **+** (Add connection)
3. Choose **Wi-Fi**
4. Enter SSID: your school WiFi name
5. Security: **WPA/WPA2 Enterprise**
6. Authentication: **PEAP**
7. Inner authentication: **MSCHAPv2**
8. Username: your school username
9. Password: your school password
10. Click **Save**
11. Connect via nm-applet

---

### Verification

```bash
# Check NetworkManager is running
systemctl status NetworkManager

# Check iwd is disabled
systemctl status iwd

# List network devices
nmcli device status
```

You should see `wlan0` and NetworkManager active, iwd inactive.

---

### How to Undo (Revert to iwd)

```bash
# Stop NetworkManager
sudo systemctl stop NetworkManager
sudo systemctl disable NetworkManager

# Re-enable iwd
sudo systemctl enable iwd
sudo systemctl start iwd

# Revert waybar config back to "omarchy-launch-wifi"
nano ~/.config/waybar/config.jsonc
# Change "on-click": "nm-applet --indicator" back to "on-click": "omarchy-launch-wifi"

# (Optional) Remove nm-applet autostart
sudo rm /etc/xdg/autostart/nm-applet.desktop

# Reboot
sudo reboot

```

---

**Done! You now have NetworkManager with full 802.1X support, same as KDE**.
