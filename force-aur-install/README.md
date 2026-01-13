# Force AUR Installation When Package Exists in Omarchy Repo

## Problem

When a package exists in both the Omarchy Package Repository (OPR) and AUR, `yay` will always prefer the Omarchy repo version. If the Omarchy repo version is broken (404 error) or outdated, you need to force installation from AUR.

**Example Error:**

```
error: failed retrieving file 'voxtype-bin-0.4.9-1-x86_64.pkg.tar.zst' from pkgs.omarchy.org : The requested URL returned error: 404
```

## Solution

Use the `aur/` prefix to explicitly tell `yay` to install from AUR, bypassing the Omarchy repo.

### Quick Method (Recommended)

```bash
# Install directly from AUR using explicit source
yay -S aur/package-name
```

**Example:**

```bash
yay -S aur/voxtype-bin
```

### Alternative Method (If Quick Method Doesn't Work)

If the quick method still tries to use the repo, temporarily add the package to `IgnorePkg`:

```bash
# Step 1: Add package to IgnorePkg
sudo sed -i '/^HoldPkg = pacman glibc/a IgnorePkg = package-name' /etc/pacman.conf

# Step 2: Install from AUR
yay -S aur/package-name

# Step 3: Remove IgnorePkg after installation
sudo sed -i '/^IgnorePkg = package-name$/d' /etc/pacman.conf
```

**Example:**

```bash
sudo sed -i '/^HoldPkg = pacman glibc/a IgnorePkg = voxtype-bin' /etc/pacman.conf
yay -S aur/voxtype-bin
sudo sed -i '/^IgnorePkg = voxtype-bin$/d' /etc/pacman.conf
```

## Why This Works

- The `aur/` prefix explicitly tells `yay` to search and install from AUR only
- `IgnorePkg` tells pacman/yay to ignore the package from repositories
- Combined, this ensures AUR installation even when the package exists in OPR

## Notes

- The `aur/` prefix is the key - it's what actually forces AUR installation
- `IgnorePkg` is optional but can help avoid conflicts
- Always remove `IgnorePkg` after installation to restore normal behavior
- This is the official Arch Linux way to handle broken repo packages

## Verification

After installation, verify it came from AUR:

```bash
pacman -Qi package-name | grep "Repository"
# Should show: Repository      : aur
```
