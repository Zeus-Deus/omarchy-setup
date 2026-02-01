#!/usr/bin/env bash
set -euo pipefail

echo "=== Btrfs Health Check ==="
sudo btrfs filesystem usage / | grep -E 'Device (un)?allocated|Metadata'

unalloc=$(sudo btrfs filesystem usage / | awk '/Device unallocated:/ {print $3}' | sed 's/GiB//')

if (( $(echo "$unalloc < 5" | bc -l) )); then
  echo "⚠️  WARNING: Unallocated space is low (${unalloc}GiB)."
  echo "Run 'sudo btrfs balance start -dusage=5 /' before updating."
  exit 1
fi

echo "✓ Btrfs health OK. Safe to update."
