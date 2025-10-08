# https://asus-linux.org/guides/arch-guide/

# Repo's
sudo pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35

# Now add the repository to /etc/pacman.conf :
sudo nvim /etc/pacman.conf

# Add at the end of the file:
[g14]
Server = https://arch.asus-linux.org

# Then update package databases:
sudo pacman -Syu

# Installing asusctl:
sudo pacman -S asusctl power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon.service

# GUI tool for configuring few aspects of asusctl and supergfxctl.
sudo pacman -S rog-control-center

# This package configures NVIDIA Dynamic Power Management specifically for laptops.
git clone https://gitlab.com/asus-linux/nvidia-laptop-power-cfg.git
cd nvidia-laptop-power-cfg
makepkg -sfi
# During the installation I got this message: warning: /etc/modprobe.d/nvidia.conf installed as /etc/modprobe.d/nvidia.conf.pacnew
# The file already existed so it gave the new one a diffrent name which would result in not recognising the new. 
# Ive inspected both and the new one has what the old one had + more so I ran this to replace it (if you had no warning then skip this):
sudo mv /etc/modprobe.d/nvidia.conf.pacnew /etc/modprobe.d/nvidia.conf

# Check NVIDIA Services Status:
systemctl list-unit-files | grep nvidia

# Enable NVIDIA Services:
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
sudo systemctl enable --now nvidia-powerd

# Then verify it's enabled:
systemctl list-unit-files | grep nvidia

# After this restart the computer.

# Make sure you install the vulkan adapter for mesa as well, on Omarchy they come installed:
# See if you have them:
pacman -Q nvidia-utils vulkan-icd-loader

# If you dont, install:
sudo pacman -S nvidia-utils vulkan-icd-loader

