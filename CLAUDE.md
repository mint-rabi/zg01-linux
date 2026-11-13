# CLAUDE.md — handoff notes for zg01-linux

This repository makes the Yamaha ZG01 (USB game streaming mixer) usable on Linux
as a mic/speaker for voice chat apps. It contains only config files and scripts;
no kernel code yet. The investigation below was done in a claude.ai chat and
verified on real hardware. Respond to the owner in Japanese unless asked otherwise.

## Repository layout

- `config/modprobe.d/zg01.conf` — `options snd_usb_audio quirk_alias=04991513:04991509`
- `config/wireplumber/51-zg01.conf` — forces capture `audio.format = "S32LE"`
- `config/pipewire/zg01.conf` — loopbacks: "ZG01 Mic" (capture RL/RR) and "ZG01 Chat" (playback AUX8/AUX9)
- `install.sh` / `uninstall.sh`
- `README.md` (English) / `README.ja.md` (Japanese) — keep both in sync

## Device facts (from `lsusb -v`)

- VID:PID `0499:1513`, bcdDevice 1.50, high speed, bDeviceClass 239 (IAD)
- All interfaces are bInterfaceClass 255 (vendor), but bInterfaceProtocol 0x20
  (UAC2) and SubClass 1/2/3 = AudioControl/AudioStreaming/MIDI. The
  class-specific descriptors are standard UAC2.
- if0: AudioControl. Clock source ID 1 (internal programmable).
  IT 2 (USB streaming, 10 ch) -> OT 3; IT 4 (4 ch) -> OT 5 (USB streaming).
- if1 alt1: playback, 10 ch, subslot 4 bytes / 32 bit, EP 0x01 OUT iso async,
  wMaxPacketSize 280 (= 7 frames x 10 ch x 4 bytes, 48 kHz only).
- if2 alt1: capture, 4 ch, 32 bit, EP 0x81 IN iso "implicit feedback data"
  (used as sync for playback), plus EP 0x84 interrupt IN.
  AS_GENERAL bmFormats = 0xffffffff (bogus; kernel logs
  "unsupported format bits 0xfffffffe" and exposes U8/FLOAT_LE/MU_LAW/... too).
- if3: Yamaha-style MIDI (bulk EP 0x02/0x82). if4: vendor (bulk EP 0x03/0x83).

## Why it fails by default

- No quirk entry for 0x1513 in `sound/usb/quirks-table.h`.
- The Yamaha vendor-wide QUIRK_AUTODETECT path (`create_auto_pcm_quirk`)
  requires a format type descriptor of >= 8 bytes (UAC1 style); the ZG01's
  UAC2 format type descriptor is 6 bytes, so audio is rejected and only MIDI
  is created ("Quirk or no altset; falling back to MIDI 1.0").
- Upstream mainline has an entry for the ZG02 (0x1516): composite
  STANDARD_AUDIO(1), STANDARD_AUDIO(2), MIDI_YAMAHA(3), IGNORE(4), plus
  `DEVICE_FLG(0x0499, 0x1516, QUIRK_FLAG_GENERIC_IMPLICIT_FB)` in quirks.c.
  Ubuntu 26.04's kernel (7.0.0-30) does NOT contain the ZG02 entry.
- The Steinberg UR22 (0x1509) entry has the identical layout and flag and is
  present in old kernels, so `quirk_alias=04991513:04991509` works. The alias
  id becomes chip->usb_id, so the UR22 quirk flags apply too.

## Verified results (Ubuntu 26.04 live USB, kernel 7.0.0-30-generic, PipeWire 1.6.2)

- dmesg: `applying quirk alias 0499:1509`; card "Yamaha ZG01" created.
- /proc/asound stream: playback 10 ch S32_LE 48000, implicit feedback from
  EP 0x81; capture 4 ch 48000 (format list polluted by bmFormats).
- `aplay -D hw:ZG01` of a 10 ch S32 file with a tone on one channel at a time:
  all channels audible in headphones. `speaker-test -f S32_LE` failed with
  "Sample format not available" (speaker-test issue; aplay works).
- Capture: ch2/3 = mic (identical, mono duplicated). ch0/1 = streaming mix,
  always silent because ZG Controller had STREAMING OUTPUT USB = OFF (default).
- PipeWire nodes: sink `alsa_output.usb-Yamaha_Corporation_Yamaha_ZG01-00.multichannel-output`
  (10 ch AUX0-9; only aux0/1 at 100% by default), source
  `alsa_input.usb-Yamaha_Corporation_Yamaha_ZG01-00.analog-surround-40`
  (4 ch FL FR RL RR, path surround40:5). Without the WirePlumber rule the
  source runs as float32le (wrong). With the rule it is s32le and the mic works.
- "ZG01 Chat" + "ZG01 Mic" tested OK with a web mic test.
- Mic level is low with an Audio-Technica AT2040 (low-output dynamic); this is
  a gain issue (same on Windows), not a Linux bug.

## Channel mapping (from the ZG01 manual + tests)

- Playback ch0-7: "Speaker (Yamaha ZG01)" = Game bus, 7.1 surround.
  Exact per-channel order is not verified (ch4 was heard on the right side,
  probably due to the ZG01's surround-to-headphone processing).
- Playback ch8-9: "Voice (Yamaha ZG01)" = voice chat bus (chat level knob).
- Capture ch0-1: "Streaming (Yamaha ZG01)" = streaming mix (needs ZG Controller
  STREAMING OUTPUT MIXER -> USB ON; not sent when HDMI input is HDCP-protected).
- Capture ch2-3: "Voice (Yamaha ZG01)" = mic only.
- ZG Controller settings are stored in the device (inferred from the manual:
  factory reset "returns the unit's settings"; PC-less usage scenario).

## TODO / ideas

1. Upstream kernel patch (owner has not decided to do this; ask first):
   - `sound/usb/quirks-table.h`: add 0x1513 mirroring the ZG02 entry.
   - `sound/usb/quirks.c`: `DEVICE_FLG(0x0499, 0x1513, QUIRK_FLAG_GENERIC_IMPLICIT_FB)`.
   - Separate patch: handle the bogus capture bmFormats (e.g. fixed format
     quirk) — discuss approach with ALSA maintainers.
   - Send via git send-email to recipients from scripts/get_maintainer.pl.
2. Verify the streaming mix on Linux after enabling USB output in ZG Controller.
3. Optional: "ZG01 Game" virtual sink (AUX0-7 as 7.1), verify 7.1 channel order.
4. Optional: make the PipeWire config robust to different node names/profiles.
5. Optional: a script to collect diagnostics (dmesg, /proc/asound, wpctl, pactl).

## Notes

- Testing needs real hardware; VMware USB passthrough did not expose the ZG01,
  and WSL2 lacks snd-usb-audio.
- Do not redistribute Yamaha drivers, firmware, manuals or logos.
