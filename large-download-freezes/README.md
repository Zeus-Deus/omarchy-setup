# Omarchy: Large Download Freezes Fix

This folder contains a collection of scripts to permanently fix short, periodic "Application Not Responding" dialogs, massive CPU spikes, and system freezes that occur during large downloads (like Steam games, ComfyUI models, or heavy torrents) on Linux/Btrfs systems.

## 🚀 How to apply everything at once (Recommended)

To run all the fixes automatically in sequence, simply run the master script:

```bash
chmod +x main.sh
./main.sh
```

The master script will guide you through the 3 individual fixes detailed below. If you prefer, you can run any of them manually instead.

---

## Part 1: RAM Cache Dirty-Bytes Fix (`sysctl-dirty-bytes-fix.sh`)

**The Issue:** The Linux kernel by default uses percentage-based dirty-page thresholds (`vm.dirty_background_ratio` / `vm.dirty_ratio`). On systems with lots of RAM, this allows many gigabytes of unwritten data to accumulate in memory. When the kernel is finally forced to flush this massive cache to your SSD, it blocks other system writes and causes UI freezing and stuttering.

**The Fix:** Switches from ratio-based limits to fixed byte thresholds (~128 MB / ~256 MB), forcing the kernel to do smaller, much more frequent flushes that don't block the system.

**How to run manually:**
```bash
chmod +x sysctl-dirty-bytes-fix.sh
./sysctl-dirty-bytes-fix.sh
```

---

## Part 2: Downloads & ComfyUI NOCOW Fix (`btrfs-nocow-fix.sh`)

**The Issue:** Linux uses the **Btrfs** file system, which utilizes **Copy-on-Write (CoW)** to create system snapshots (like via Snapper). When you download massive files, CoW continuously scatters tiny data chunks into hundreds of thousands of microscopic fragments across your disk to preserve the "old" file state. This extreme fragmentation instantly chokes your CPU and SSD.

**The Fix:** This script safely converts your `~/Downloads` and `~/comfyui` folders into independent Btrfs subvolumes and applies the `+C` (No Copy-on-Write) attribute to them.

**How to run manually:**
```bash
chmod +x btrfs-nocow-fix.sh
./btrfs-nocow-fix.sh
```

---

## Part 3: Steam Games NOCOW Library Fix (`btrfs-nocow-steam-games.sh`)

### ⚠️ IMPORTANT: Why Steam requires a different approach ⚠️
Applying the NOCOW (`+C`) flag directly to your default `~/.local/share/Steam` library is fundamentally incompatible with Proton and Wine.
If Proton runtime folders, wine prefixes (`compatdata/`), or game executables (`.exe`/`.dll`) receive the NOCOW flag, the specific memory mapping that Wine relies on breaks, and **games will instantly crash or fail to launch with an "Exec format error"**.

**The Solution:**
Steam has a fantastic built-in multi-library system. When you create a secondary game library, Steam is smart enough to know the difference between "Games" and "Tools".
Even if you tell Steam to make your secondary library the default for new installations, **Steam will automatically force tools like Proton, Steam Linux Runtime, and Shader Caches to stay safely in the primary `~/.local/share/Steam` library.** 

This script creates a safe, NOCOW-enabled `~/Games` directory for you to store massive games in:

**How to run manually:**
```bash
chmod +x btrfs-nocow-steam-games.sh
./btrfs-nocow-steam-games.sh
```

**After running the script:**
1. Open Steam.
2. Go to **Settings > Storage > Add Drive**.
3. Select the new `~/Games` folder.
4. **Make it default for future games:** Select the `~/Games` drive from the dropdown, click the **`...`** (three dots) button on the right, and choose **"Make Default"**. Every new game you download will automatically go here and be lag-free.
5. **For existing games:** Select your old drive from the dropdown, check the box next to your heavy game, and click **Move** to transfer it to the `~/Games` drive.

*Note: You can also use this `~/Games` folder for Lutris, Heroic Games Launcher, Epic Games, or any other massive files you want to download without system lag!*
