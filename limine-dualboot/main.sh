#!/usr/bin/env bash
set -euo pipefail

# Purpose: Add a Windows chainload entry to Limine without copying any Windows files.
# This script assumes:
#  - You boot Linux via Limine on UEFI
#  - Your ESP (EFI System Partition) for Linux is mounted at /boot
#  - Windows' ESP has label "SYSTEM" (as shown by lsblk)

WIN_ESP_LABEL=${WIN_ESP_LABEL:-SYSTEM}
MOUNT_POINT=/mnt/winboot
LIMINE_CFG_CANDIDATES=(
  "/boot/limine.conf"
  "/boot/limine/limine.conf"
)

# Ensure cleanup even if the script exits early
cleanup() {
  sudo umount "${MOUNT_POINT}" 2>/dev/null || true
  rmdir "${MOUNT_POINT}" 2>/dev/null || true
}
trap cleanup EXIT

echo "[1/4] Locating Windows ESP by label '${WIN_ESP_LABEL}'..."
WIN_ESP_DEV="/dev/disk/by-label/${WIN_ESP_LABEL}"
if [ ! -e "${WIN_ESP_DEV}" ]; then
  echo "ERROR: Could not find /dev/disk/by-label/${WIN_ESP_LABEL}."
  echo "Hint: Check labels with: lsblk -o NAME,LABEL,PATH" >&2
  exit 1
fi

echo "[2/4] Mounting Windows ESP read-only and verifying bootmgfw.efi..."
sudo mkdir -p "${MOUNT_POINT}"
if mountpoint -q "${MOUNT_POINT}"; then
  echo " - ${MOUNT_POINT} already mounted, skipping mount"
else
  sudo mount -o ro "${WIN_ESP_DEV}" "${MOUNT_POINT}"
fi

if [ ! -f "${MOUNT_POINT}/EFI/Microsoft/Boot/bootmgfw.efi" ]; then
  echo "ERROR: ${MOUNT_POINT}/EFI/Microsoft/Boot/bootmgfw.efi not found."
  echo "Contents of ${MOUNT_POINT}/EFI/Microsoft/Boot (if any):" >&2
  ls -la "${MOUNT_POINT}/EFI/Microsoft/Boot" || true
  echo "Ensure you're pointing to the correct Windows ESP (likely the one with label 'SYSTEM')." >&2
  exit 1
fi

echo "[3/4] Determining Limine configuration file..."
LIMINE_CFG=""
for cfg in "${LIMINE_CFG_CANDIDATES[@]}"; do
  if [ -f "$cfg" ]; then
    LIMINE_CFG="$cfg"
    break
  fi
done

if [ -z "$LIMINE_CFG" ]; then
  # Default to /boot/limine.conf (preferred location per Limine docs)
  LIMINE_CFG="/boot/limine.conf"
  echo " - No existing limine.conf found, creating ${LIMINE_CFG}"
  sudo install -D -m 0644 /dev/null "$LIMINE_CFG"
fi

echo "Using Limine config: $LIMINE_CFG"

# Build the entry to add (use efi_chainload + image_path for consistency)
ENTRY="$(cat <<EOF
/Windows
  comment: Boot Windows (chainload bootmgfw.efi from ESP label ${WIN_ESP_LABEL})
  protocol: efi_chainload
  image_path: fslabel(${WIN_ESP_LABEL}):/EFI/Microsoft/Boot/bootmgfw.efi
EOF
)"

# Idempotent append: only add if a matching Windows chainload line isn't already present
# Detect both legacy 'path:' and preferred 'image_path:' keys
if grep -Eq "(image_path|path): fslabel\(${WIN_ESP_LABEL}\):/EFI/Microsoft/Boot/bootmgfw\.efi" "$LIMINE_CFG"; then
  echo "[4/4] Windows entry already present in ${LIMINE_CFG}. Nothing to do."
else
  echo "[4/4] Appending Windows entry to ${LIMINE_CFG}..."
  printf "\n%s\n" "$ENTRY" | sudo tee -a "$LIMINE_CFG" >/dev/null
  echo " - Entry added. You can adjust timeout/default_entry at the top of ${LIMINE_CFG} if desired."
fi

echo "Done. Reboot and select 'Windows' in Limine."