# zg01-linux

**English** | [日本語](README.ja.md)

Configuration files for using the **Yamaha ZG01** game streaming mixer on Linux as a microphone and speaker for voice chat apps (Zoom, Slack huddles, Discord, etc.).

> **Unofficial.** This project is not affiliated with or endorsed by Yamaha Corporation. No warranty. Use at your own risk.

## Status

| Function | Status |
|---|---|
| Recognized as an audio device | ✅ (with the modprobe option below) |
| Playback (10 ch) | ✅ |
| Microphone capture | ✅ |
| Voice chat via "ZG01 Chat" / "ZG01 Mic" | ✅ |
| Streaming mix capture | ⚠️ Not verified (see below) |
| ZG Controller features (effects, mixer settings) | ❌ Not available on Linux |

Tested on Ubuntu 26.04 (kernel 7.0.0-30-generic, PipeWire / WirePlumber 1.6.2).

## Why it doesn't work out of the box

The ZG01 (USB ID `0499:1513`) is internally a USB Audio Class 2.0 device, but its interfaces are labeled as vendor-specific class (255). The Linux kernel only knows how to handle it when a quirk entry exists, and there is none for the ZG01 yet (there is one for its sibling, the ZG02). Without it, the ZG01 shows up only as a MIDI device.

The Steinberg UR22 (`0499:1509`) has the same interface layout, so this project tells the kernel to treat the ZG01 like a UR22.

## Installation

```bash
git clone https://github.com/mint-rabi/zg01-linux.git
cd zg01-linux
./install.sh
```

The script installs three files:

| File | Purpose |
|---|---|
| `/etc/modprobe.d/zg01.conf` | Make the kernel driver recognize the ZG01 |
| `~/.config/wireplumber/wireplumber.conf.d/51-zg01.conf` | Fix the capture sample format (S32LE) |
| `~/.config/pipewire/pipewire.conf.d/zg01.conf` | Create the "ZG01 Mic" and "ZG01 Chat" virtual devices |

Then, in your voice chat app, select:

- **Output: ZG01 Chat**
- **Input: ZG01 Mic**

No changes are needed in ZG Controller for voice chat use.

To uninstall, run `./uninstall.sh`.

## Channel layout

**Playback (10 ch, S32_LE, 48 kHz)**

| Channels | ZG01 bus | Windows device name |
|---|---|---|
| 0–7 | Game (7.1 surround) | Speaker (Yamaha ZG01) |
| 8–9 | Voice chat | Voice (Yamaha ZG01) |

**Capture (4 ch, S32_LE, 48 kHz)**

| Channels | ZG01 bus | Windows device name |
|---|---|---|
| 0–1 | Streaming mix | Streaming (Yamaha ZG01) |
| 2–3 | Microphone | Voice (Yamaha ZG01) |

"ZG01 Chat" outputs to the voice chat bus, so its volume follows the voice chat level knob on the ZG01. Sound sent to the default "Yamaha ZG01 Multichannel" output goes to the Game bus (ch 0–1).

## Troubleshooting

**The ZG01 does not appear at all**
Check that the alias is applied: `sudo dmesg | grep "quirk alias"` should show `applying quirk alias 0499:1509`. Replug the ZG01 or reboot after installing.

**"ZG01 Mic" / "ZG01 Chat" do not appear**
The config assumes the default PipeWire node names. Check them with `wpctl status` or `pactl list short sources` and edit `target.object` in `config/pipewire/zg01.conf` if they differ.

**The microphone is noisy or silent**
Make sure the capture format is S32LE: `pactl list short sources | grep -i zg01` should show `s32le`. If it shows `float32le`, the WirePlumber rule is not applied (WirePlumber 0.5 or later is required).

**The microphone level is low**
Low-output dynamic microphones may need the gain knob near maximum. Speak closer to the mic, use an inline mic booster (phantom powered), or boost in software: `wpctl set-volume <ID of ZG01 Mic> 2.0`.

**The streaming mix (capture ch 0–1) is silent**
By default the ZG01 sends the streaming mix only to HDMI OUT. Turning on "USB" in the STREAMING OUTPUT MIXER screen of ZG Controller (Windows/Mac) should route it to USB. The setting appears to be stored in the device, but this has not been verified on Linux. The mix is also not sent to USB when the HDMI input is HDCP-protected.

## Reporting problems

Run the diagnostics script as your normal user (not with sudo) and attach the
generated `zg01-diag-*.txt` to a GitHub issue:

```bash
./collect-diagnostics.sh
```

It collects the USB descriptors, kernel log lines, `/proc/asound` info, installed
config status and PipeWire state. The user name, host name and USB serial number
are masked, but please review the file before posting.

## License

MIT
