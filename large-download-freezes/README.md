# Fix: Small periodic system freezes during downloads

This fixes short, periodic "Application Not Responding" dialogs and brief system freezes that can occur during large downloads or heavy disk I/O on systems with lots of RAM.

Symptoms

- Short UI freezes or "Application Not Responding" during downloads
- Browsers or download tools become briefly unresponsive

Cause

- The Linux kernel by default uses percentage-based dirty-page thresholds (`vm.dirty_background_ratio` / `vm.dirty_ratio`). On large-RAM systems that allows many gigabytes of unwritten data to accumulate, and when the kernel forces a flush it can block writes and cause system-wide stutters.

What this change does

- Switches from ratio-based thresholds to fixed byte thresholds so the kernel does smaller, more frequent flushes:
  - `vm.dirty_background_bytes = 4194304` (4 MiB)
  - `vm.dirty_bytes = 4194304` (4 MiB)

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
vm.dirty_background_bytes = 4194304
vm.dirty_bytes = 4194304
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
- After: fixed byte limits of ~4 MiB for both background and hard thresholds

Reference

- Arch Wiki: https://wiki.archlinux.org/title/sysctl#Small_periodic_system_freezes
