#!/bin/bash
# Install configuration files for using the Yamaha ZG01 on Linux.
set -e
cd "$(dirname "$0")"

WP_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
PW_DIR="$HOME/.config/pipewire/pipewire.conf.d"

echo "[1/4] Installing /etc/modprobe.d/zg01.conf (sudo)"
sudo install -m 644 config/modprobe.d/zg01.conf /etc/modprobe.d/zg01.conf

echo "[2/4] Installing WirePlumber / PipeWire config"
mkdir -p "$WP_DIR" "$PW_DIR"
install -m 644 config/wireplumber/51-zg01.conf "$WP_DIR/51-zg01.conf"
install -m 644 config/pipewire/zg01.conf       "$PW_DIR/zg01.conf"

echo "[3/4] Reloading snd_usb_audio and restarting PipeWire"
systemctl --user stop pipewire pipewire-pulse wireplumber pipewire.socket pipewire-pulse.socket 2>/dev/null || true
if sudo modprobe -r snd_usb_audio 2>/dev/null; then
  sudo modprobe snd_usb_audio
else
  echo "  snd_usb_audio is in use. Unplug and replug the ZG01 (or reboot) to apply."
fi
systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber
sleep 5

echo "[4/4] Setting all channels of the ZG01 output to 100%"
ID=$(wpctl status | grep -m1 "Yamaha ZG01 Multichannel" | grep -oE '[0-9]+\.' | head -1 | tr -d .)
if [ -n "$ID" ]; then
  wpctl set-volume "$ID" 1.0
  echo "  done (node $ID)"
else
  echo "  ZG01 output not found. Connect the ZG01 and run:"
  echo "    wpctl set-volume <ID of 'Yamaha ZG01 Multichannel'> 1.0"
fi

echo
echo "Finished. In your apps, select:"
echo "  Output: ZG01 Chat"
echo "  Input : ZG01 Mic"
