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

## Part 2: Fixing Lag Caused by BTRFS Copy-on-Write (The "Lingering Lag" Fix)

Linux uses the **Btrfs** file system, which utilizes **Copy-on-Write (CoW)**. When an app updates a file, Btrfs writes the new data to a new location on the disk rather than overwriting it.

When you download massive files (like large ComfyUI models or Steam Games), this scattered writing process alongside compression absolutely chokes your CPU and SSD. We can fix this by applying the NOCOW (`+C`) attribute to those directories.

### How to Apply NOCOW to Downloads & ComfyUI

A script has been provided to automatically convert your `Downloads` and `comfyui` folders into subvolumes, apply the `+C` (No Copy-on-Write) attribute, and safely move your data over.

1. **Close ComfyUI** completely.
2. Close your web browsers so nothing is writing to the Downloads folder.
3. Run the script:
   ```bash
   ./btrfs-nocow-fix.sh
   ```

### ⚠️ IMPORTANT: Why Steam requires a different approach ⚠️

Applying the NOCOW (`+C`) flag directly to your default `~/.local/share/Steam` library is fundamentally incompatible with Proton and Wine.
If Proton runtime folders, wine prefixes (`compatdata/`), or game executables (`.exe`/`.dll`) receive the NOCOW flag, the specific memory mapping that Wine relies on breaks, and **games will instantly crash or fail to launch with an "Exec format error"**.

**How does Steam handle multiple directories?**
Steam has a fantastic built-in multi-library system. When you create a secondary game library, Steam is smart enough to know the difference between "Games" and "Tools". 
Even if you tell Steam to make your secondary library the default for new installations, **Steam will automatically force tools like Proton, Steam Linux Runtime, and Shader Caches to stay in the primary `~/.local/share/Steam` library.** 
This behavior is exactly what we want! It allows Proton to run perfectly safely with standard Copy-on-Write, while your massive game files enjoy lag-free NOCOW downloads.

### How to safely use NOCOW for Steam Games

Run the dedicated Steam Games script to create a safe, NOCOW-enabled `~/Games` directory:

```bash
./btrfs-nocow-steam-games.sh
```

**Does it matter if Steam is installed yet?**
No! You can run this script on a fresh Omarchy install before Steam is even downloaded. It just creates a normal folder on your system and flags it with NOCOW. You can also run it on an old system that already has games installed.

**After running the script:**
1. Open Steam.
2. Go to **Settings > Storage > Add Drive**.
3. Select the `~/Games` folder.
4. **Make it default for future games:** Select the `~/Games` drive from the dropdown, click the **`...`** (three dots) button on the right, and choose **"Make Default"**. Every new game you download will automatically go here and be lag-free.
5. **For existing games:** Select your old drive from the dropdown, check the box next to your heavy game (like God of War), and click **Move** to transfer it to the `~/Games` drive.

*Note: You can also use this `~/Games` folder for Lutris, Heroic Games Launcher, Epic Games, or any other massive files you want to download without system lag!*
