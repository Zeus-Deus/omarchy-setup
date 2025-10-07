# Limine Windows Chainload (Quick Setup)

Add a Windows boot entry to the Limine bootloader without copying any Microsoft files. The script chainloads Windows directly from its own EFI System Partition (ESP) using the partition label.

## Requirements

- UEFI firmware (not legacy BIOS)
- Limine installed and used as your system bootloader
- Linux ESP mounted and writable (script targets one of: `/boot/limine.conf`, `/boot/limine/limine.conf`)
- Windows ESP present with the standard loader at `EFI/Microsoft/Boot/bootmgfw.efi`
- Default Windows ESP label is `SYSTEM` (adjustable)

Check disks/labels:

```bash
lsblk -o NAME,FSTYPE,LABEL,FSAVAIL,FSUSE%,MOUNTPOINTS
```

## Quick start

```bash
# Make the script executable and run it
chmod +x ~/Documents/limine-dualboot/main.sh
bash ~/Documents/limine-dualboot/main.sh

# Reboot and select "Windows" in the Limine menu
```

The script is idempotent: running it again won’t create duplicates.

## Option: custom Windows ESP label

Default label is `SYSTEM`. Override when needed:

```bash
WIN_ESP_LABEL="YOUR_LABEL" bash ~/Documents/limine-dualboot/main.sh
```

## What the script does

- Mounts the Windows ESP read-only and verifies `EFI/Microsoft/Boot/bootmgfw.efi`
- Finds or creates `limine.conf` at a standard location
- Appends a Windows entry using chainload by label:

```
/Windows
    protocol: efi_chainload
    image_path: fslabel(SYSTEM):/EFI/Microsoft/Boot/bootmgfw.efi
```

## Tips and troubleshooting

- No Limine menu? Ensure firmware boots the disk/entry where Limine is installed (before Windows Boot Manager).
- Secure Boot: either disable it or properly sign Limine and enroll the config hash (see Limine docs: Secure Boot).
- Wrong label? Use `lsblk` to find the correct label and set `WIN_ESP_LABEL` accordingly.
- Timeout/default entry: set at the top of `limine.conf`, e.g. `timeout: 5`, `remember_last_entry: yes`, `default_entry: 1`.

## Safety

- Does not copy or modify Windows files on the Windows ESP.
- Only edits your Limine config on the Linux ESP.
- Safe to run multiple times.
