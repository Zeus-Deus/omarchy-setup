# Btrfs ENOSPC Recovery Guide

## What Happened

Btrfs filesystem ran out of **unallocated space** (~1MB left) and **metadata** was 90%+ full, even though `df -h` showed ~70GB free. During a system update, Btrfs couldn't allocate new metadata chunks and threw "No space left on device" errors, eventually forcing the filesystem read-only.

**Why:** Btrfs uses separate "chunks" for data and metadata. When all raw disk space is allocated into chunks but many are only partially full, there's no room to create new metadata chunks. The 70GB "free" was space _inside_ existing data chunks, not usable for metadata allocation.

## Emergency Fix (via Live USB)

### Steps Used

1. **Boot live USB** (any Arch/Omarchy ISO works)

2. **Identify and unlock encrypted disk:**

   ```bash
   lsblk
   sudo cryptsetup open /dev/nvme0n1p2 cryptroot  # replace with your partition
   ```

3. **Mount root filesystem:**

   ```bash
   sudo mount /dev/mapper/cryptroot /mnt
   ```

4. **Run limited balance to reclaim unallocated space:**

   ```bash
   sudo btrfs balance start -dusage=5 /mnt
   ```

   This consolidates underfilled data chunks and frees up "unallocated" space.

5. **Verify fix:**

   ```bash
   sudo btrfs filesystem usage /mnt
   ```

   Check that "Device unallocated" is now several GiB (was ~1MB before).

6. **Clean up and reboot:**
   ```bash
   sudo umount /mnt
   sudo cryptsetup close cryptroot
   sudo reboot
   ```

### Result

After balance: **33.46 GiB unallocated** regained, metadata dropped to 82.84%, system boots normally.

---

## Prevention: Manual Pre-Update Check

Use the included `preupdate-btrfs.sh` script to check disk health **before** running updates. It warns you if unallocated space is too low.

**Usage:**

```bash
./preupdate-btrfs.sh && omarchy update
```

This acts as a safety guard—update only runs if the health check passes.

---

## Prevention: Automatic Monthly Maintenance (Recommended)

Install **btrfsmaintenance** to automatically run balance operations monthly. This prevents the issue from ever happening again.

**Installation:**

```bash
yay -S btrfsmaintenance
sudo systemctl enable --now btrfs-balance.timer
```

**Verify it's active:**

```bash
systemctl status btrfs-balance.timer
```

You should see `Active: active (waiting)` and a "Trigger" date showing when the next balance will run (typically monthly on the 1st).

**What it does:** Automatically runs `btrfs balance` on a schedule to keep unallocated space healthy and prevent metadata exhaustion.
