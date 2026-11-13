#!/bin/bash
set -e
sudo rm -f /etc/modprobe.d/zg01.conf
rm -f "$HOME/.config/wireplumber/wireplumber.conf.d/51-zg01.conf"
rm -f "$HOME/.config/pipewire/pipewire.conf.d/zg01.conf"
systemctl --user restart pipewire pipewire-pulse wireplumber || true
echo "Removed. Replug the ZG01 or reboot to fully revert the driver setting."
