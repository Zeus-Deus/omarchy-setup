# Step-by-Step Guide: Configuring eduroam on Omarchy Linux with iwd

## Problem

Connection to eduroam (WPA2-Enterprise/802.1x) doesn't work with iwd on Omarchy Linux.

## Step 1: Create eduroam configuration

**File:** `/var/lib/iwd/eduroam.8021x`

```bash
sudo nano /var/lib/iwd/eduroam.8021x
```

**Contents:**

```
[Security]
EAP-Method=PEAP
EAP-Identity=anonymous@edu.com
EAP-PEAP-Phase2-Method=MSCHAPV2
EAP-PEAP-Phase2-Identity=smail@edu.com
EAP-PEAP-Phase2-Password=yourpassword

[Settings]
AutoConnect=true
```

**Explanation:**

- Anonymous identity = outer identity for eduroam
- Phase2 identity/password = real credentials
- No certificate needed (often gets blocked)

**Set permissions:**

```bash
sudo chmod 600 /var/lib/iwd/eduroam.8021x
```

## Step 2: Configure iwd

**File:** `/etc/iwd/main.conf`

```bash
sudo nano /etc/iwd/main.conf
```

**Contents:**

```
[General]
EnableNetworkConfiguration=false

[Network]
EnableIPv6=true
NameResolvingService=systemd
```

**Explanation:** iwd only handles wifi authentication, systemd-networkd manages IP/DNS (prevents conflicts).

## Step 3: Configure systemd-networkd

**File:** `/etc/systemd/network/20-wlan.network`

Check if it already exists:

```bash
sudo cat /etc/systemd/network/20-wlan.network
```

Add under `[DHCPv4]`:

```
UseDNS=yes
```

**Complete configuration should be:**

```
[Match]
Name=wl*

[Network]
DHCP=yes

[DHCPv4]
RouteMetric=600
UseDNS=yes
```

**Explanation:** Ensures systemd-networkd accepts DNS from DHCP server.

## Step 4: Restart services

```bash
sudo systemctl restart systemd-networkd
sudo systemctl restart systemd-resolved
sudo systemctl restart iwd
```

## Step 5: Connect

```bash
iwctl station wlan0 connect eduroam
```

Should automatically connect without asking for credentials.

## Verification

```bash
# Check if connected
networkctl status wlan0

# Check IP address
ip addr show wlan0

# Test internet
ping google.com
```

## Note: Possible blocking

If authentication works (`EAP completed with eapSuccess`) but no internet:

- **Eduroam network likely uses MAC address filtering**
- Contact university IT helpdesk for device registration
- Provide MAC address: `ip link show wlan0` (line with "link/ether")

## What does each component do?

- **iwd**: Manages wifi connections and authentication
- **systemd-networkd**: Obtains IP address via DHCP
- **systemd-resolved**: Handles DNS (reaching websites)

This setup works for **all** wifi networks (eduroam, WPA2-PSK, etc.).
