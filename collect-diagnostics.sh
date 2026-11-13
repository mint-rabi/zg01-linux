#!/bin/bash
# Collect diagnostics for the Yamaha ZG01 on Linux into a single text file.
# Run as your normal user (not with sudo): PipeWire runs in the user session.
# The output is meant to be attached to a GitHub issue. Review it before
# posting; the user name, host name and USB serial number are masked.
#
# Usage: ./collect-diagnostics.sh [output-file]

VID_PID="0499:1513"
OUT="${1:-zg01-diag-$(date +%Y%m%d-%H%M%S).txt}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -eq 0 ]; then
  echo "Please run this as your normal user, not root (PipeWire is per-user)." >&2
  exit 1
fi

have() { command -v "$1" >/dev/null 2>&1; }

section() {
  printf '\n===== %s =====\n' "$1"
}

# run <description> <command...>: print the command and its output (stdout+stderr)
run() {
  local desc="$1"; shift
  section "$desc"
  echo "\$ $*"
  if have "$1"; then
    "$@" 2>&1
    local rc=$?
    [ $rc -ne 0 ] && echo "(exit status $rc)"
  else
    echo "($1: command not found)"
  fi
}

# show_file <path>: print a file if it exists
show_file() {
  section "$1"
  if [ -r "$1" ]; then
    cat "$1"
  else
    echo "(not found)"
  fi
}

kernel_log() {
  # dmesg is often restricted for normal users; fall back to journalctl / sudo.
  if dmesg >/dev/null 2>&1; then
    dmesg
  elif journalctl -k -b -q --no-pager >/dev/null 2>&1; then
    journalctl -k -b -q --no-pager
  elif [ -t 0 ] && have sudo; then
    echo "(dmesg needs root; asking sudo)" >&2
    sudo dmesg
  else
    echo "(could not read the kernel log)"
  fi
}

compare_config() {
  # compare_config <repo file> <installed file>
  local repo="$SCRIPT_DIR/$1" inst="$2"
  if [ ! -e "$inst" ]; then
    echo "$inst: NOT INSTALLED"
  elif [ -r "$repo" ] && cmp -s "$repo" "$inst"; then
    echo "$inst: installed (identical to repository)"
  elif [ -r "$repo" ]; then
    echo "$inst: installed (DIFFERS from repository)"
    diff -u "$repo" "$inst"
  else
    echo "$inst: installed"
    cat "$inst"
  fi
}

collect() {
  section "zg01-linux diagnostics"
  date -R
  if [ -d "$SCRIPT_DIR/.git" ] && have git; then
    echo "repository: $(git -C "$SCRIPT_DIR" describe --always --dirty 2>/dev/null)"
  fi

  section "System"
  uname -a
  [ -r /etc/os-release ] && grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release
  if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "NOTE: running under WSL (USB device attached via usbipd?)."
  fi

  run "USB device" lsusb -d "$VID_PID"
  if have lsusb && ! lsusb -d "$VID_PID" >/dev/null 2>&1; then
    echo "ZG01 ($VID_PID) NOT FOUND on the USB bus."
  fi
  run "USB descriptors" lsusb -v -d "$VID_PID"

  section "snd_usb_audio module"
  if [ -d /sys/module/snd_usb_audio ]; then
    echo "loaded: yes"
    for p in quirk_alias quirk_flags implicit_fb; do
      [ -r "/sys/module/snd_usb_audio/parameters/$p" ] &&
        echo "$p = $(cat "/sys/module/snd_usb_audio/parameters/$p")"
    done
  else
    echo "loaded: no"
    if have modinfo; then
      modinfo snd_usb_audio >/dev/null 2>&1 &&
        echo "available: yes (module not loaded)" ||
        echo "available: NO (snd-usb-audio is not built for this kernel)"
    fi
  fi

  section "Installed configuration"
  compare_config config/modprobe.d/zg01.conf /etc/modprobe.d/zg01.conf
  compare_config config/wireplumber/51-zg01.conf "$HOME/.config/wireplumber/wireplumber.conf.d/51-zg01.conf"
  compare_config config/pipewire/zg01.conf "$HOME/.config/pipewire/pipewire.conf.d/zg01.conf"

  section "Kernel log (USB audio / ZG01 related)"
  kernel_log | grep -iE '0499|1513|zg01|yamaha|snd.usb|usb-audio|quirk alias|implicit.fb|implicit feedback|unsupported format|vhci_get_frame_number' | tail -n 200

  show_file /proc/asound/cards
  local card
  for card in /proc/asound/ZG01 /proc/asound/card*; do
    [ -r "$card/id" ] || continue
    if [ "$card" = /proc/asound/ZG01 ] || grep -q ZG01 "$card/id" 2>/dev/null; then
      for f in "$card"/usbid "$card"/stream* "$card"/pcm*/sub0/hw_params; do
        [ -e "$f" ] && show_file "$f"
      done
      break
    fi
  done

  if [ ! -d /proc/asound ]; then
    echo "(/proc/asound is missing: kernel built without CONFIG_SND_PROC_FS)"
  fi
  run "Sound device nodes" ls -l /dev/snd
  section "Sound cards (sysfs)"
  local c
  for c in /sys/class/sound/card*; do
    [ -e "$c" ] || continue
    echo "$(basename "$c"): id=$(cat "$c/id" 2>/dev/null)" \
      "devices=$(ls "$c" | grep -E '^(pcm|midi|controlC)' | tr '\n' ' ')"
  done

  run "ALSA playback devices" aplay -l
  run "ALSA capture devices" arecord -l

  # Supported hardware parameters (works without /proc/asound).
  # Fails harmlessly with "Device or resource busy" while PipeWire uses it.
  if have aplay && aplay -l 2>/dev/null | grep -q ZG01; then
    run "Playback hw params" timeout 5 aplay -D hw:ZG01 --dump-hw-params -t raw -d 1 /dev/zero
    run "Capture hw params" timeout 5 arecord -D hw:ZG01 --dump-hw-params -t raw -d 1 /dev/null
  fi

  run "PipeWire version" pipewire --version
  run "WirePlumber version" wireplumber --version
  run "PipeWire services" systemctl --user --no-pager --lines=0 status pipewire wireplumber pipewire-pulse
  run "wpctl status" wpctl status
  run "pactl sinks" pactl list short sinks
  run "pactl sources" pactl list short sources

  section "PipeWire ZG01 node properties"
  if have pw-cli; then
    local id
    for id in $(pw-cli ls Node 2>/dev/null | awk '/^[[:space:]]*id [0-9]+/{gsub(",","",$2); id=$2} /node.name = .*(ZG01|zg01)/{print id}'); do
      echo "--- node $id"
      pw-cli info "$id" 2>&1 | grep -E 'node\.(name|description)|media\.class|audio\.(format|rate|channels|position)|api\.alsa\.path|state'
    done
  else
    echo "(pw-cli: command not found)"
  fi
}

mask() {
  local user host args
  user="$(id -un)"
  host="$(hostname 2>/dev/null)"
  args=(-e "s/iSerial([[:space:]]+[0-9]+[[:space:]]*).*/iSerial\1<masked>/"
        -e "s#/home/$user#/home/<user>#g")
  # Skip very short names to avoid masking unrelated words.
  [ ${#host} -ge 3 ] && args+=(-e "s/\b$host\b/<host>/g")
  [ ${#user} -ge 3 ] && args+=(-e "s/\b$user\b/<user>/g")
  sed -E "${args[@]}"
}

echo "Collecting ZG01 diagnostics..."
collect | mask > "$OUT"
echo "Saved to: $OUT"
echo "Please review the file before attaching it to a GitHub issue."
