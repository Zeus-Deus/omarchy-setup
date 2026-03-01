# Fix: Small periodic system freezes during downloads

This fixes short, periodic "Application Not Responding" dialogs and brief system freezes that can occur during large downloads or heavy disk I/O on systems with lots of RAM.

Symptoms

- Short UI freezes or "Application Not Responding" during downloads
- Browsers or download tools become briefly unresponsive

Cause

- The Linux kernel by default uses percentage-based dirty-page thresholds (`vm.dirty_background_ratio` / `vm.dirty_ratio`). On large-RAM systems that allows many gigabytes of unwritten data to accumulate, and when the kernel forces a flush it can block writes and cause system-wide stutters.

What this change does

- Switches from ratio-based thresholds to fixed byte thresholds so the kernel does smaller, more frequent flushes:
  - `vm.dirty_background_bytes = 134217728` (128 MB)
  - `vm.dirty_bytes = 268435456` (256 MB)

How to apply (recommended)

1. Make the script executable and run it from this folder:

```bash
chmod +x main.sh
./main.sh
```

The script writes `/etc/sysctl.d/99-dirty-bytes.conf` and applies the settings with `sysctl`.

How to apply (manual)

```bash
sudo tee /etc/sysctl.d/99-dirty-bytes.conf > /dev/null << 'EOF'
# Prevent large blocking dirty-page flushes during heavy disk I/O
vm.dirty_background_bytes = 134217728
vm.dirty_bytes = 268435456
EOF

sudo sysctl -p /etc/sysctl.d/99-dirty-bytes.conf
```

How to undo / revert

- Remove the file and reload sysctl settings:

```bash
sudo rm /etc/sysctl.d/99-dirty-bytes.conf
sudo sysctl -p
```

- Or comment out the two lines inside `/etc/sysctl.d/99-dirty-bytes.conf` and run:

```bash
sudo sysctl -p /etc/sysctl.d/99-dirty-bytes.conf
```

- Rebooting (after removing the file) will also restore kernel defaults.

File created by the script

- `/etc/sysctl.d/99-dirty-bytes.conf`

Before vs after (example)

- Before: `vm.dirty_background_ratio=10`, `vm.dirty_ratio=20` (percent of RAM — can be many GB)
- After: fixed byte limits of ~128 MB (background) and ~256 MB (hard) instead of multi-GB percent-based thresholds

Reference

- Arch Wiki: https://wiki.archlinux.org/title/sysctl#Small_periodic_system_freezes

## Part 2: Fixing Lag Caused by BTRFS Copy-on-Write (The "Lingering Lag" Fix)

Even after fixing the RAM cache issues above, you may still experience heavy lag, CPU usage, and high disk I/O when downloading Steam games or massive torrents.

### The Cause (BTRFS CoW & Snapper)

Linux uses the **Btrfs** file system, which utilizes **Copy-on-Write (CoW)**. When an app updates a file, Btrfs writes the new data to a new location on the disk rather than overwriting it. 

When you download a 100GB Steam game, Steam downloads compressed chunks randomly and constantly overwrites the file. Btrfs CoW scatters these updates into hundreds of thousands of microscopic fragments across your disk. Furthermore, Btrfs tries to compress these already-compressed chunks in real-time. This combination absolutely chokes your CPU and SSD.

### The Fix

We must disable CoW (`+C` attribute) and compression specifically for heavy download folders like `~/Downloads`, `~/.local/share/Steam/steamapps`, and AI tools like `~/comfyui`.

**The Snapper Catch:** Because you use Snapper for system backups, if Snapper takes a snapshot of a folder with CoW disabled, Btrfs will immediately force CoW to turn back *on* for that folder to preserve the snapshot state. This instantly brings the lag back. 
To permanently fix this, we must convert the Steam and Downloads folders into **Btrfs Subvolumes**. Snapper ignores subvolumes completely, meaning your games won't bloat your system backups, and the NOCOW fix will remain permanent forever.

### How to Apply

A script has been provided to automatically convert your `Downloads`  `steamapps`, and `comfyui` folders into subvolumes, apply the `+C` (No Copy-on-Write) attribute, and safely move your data over.

1. **Close Steam** and **ComfyUI** completely.
2. Close your web browsers (Firefox, Chrome, Brave, etc.) so nothing is writing to the Downloads folder.
3. Run the script:
   ```bash
   ./btrfs-nocow-fix.sh
   ```

*(Note: Depending on how many games you have installed, copying the data to the new subvolume can take a long time. Please be patient.)*

### Cleanup
The script renames your original folders to `Downloads_old`  `steamapps_old`, and `comfyui_old` to keep your data safe during the transfer. Once the script finishes and you verify your games and downloads are intact, you can safely delete the `_old` folders to reclaim your disk space.

```bash
rm -rf ~/Downloads_old
rm -rf ~/.local/share/Steam/steamapps_old
rm -rf ~/comfyui_old
```
