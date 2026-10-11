# LED Range Board — physical 13×13 poker range display

ESP32 + WS2812B 16×16 panel showing the hero's range grid from the app
(Statistics → Range). v0 syncs over the local network; v1 (planned) swaps
the transport for Firebase RTDB streaming so the board updates from
anywhere without the app being open.

## Parts

| Part | Notes |
|---|---|
| ESP32 dev board | Any WROOM-32 devkit (~€6) |
| WS2812B 16×16 flexible panel | 256 LEDs; we use the top-left 13×13 (~€15, BTF-Lighting or similar) |
| 5V PSU, ≥4A | Barrel jack or screw terminal. Brightness is software-capped so 4A is comfortable |
| 74AHCT125 level shifter | Shifts the ESP32's 3.3V data to 5V. (Often works without — try direct first through the resistor) |
| 330Ω resistor | In series on the data line, close to the panel |
| 1000µF electrolytic cap | Across panel 5V/GND, protects first LEDs at power-on |

## Wiring

```
PSU 5V  ──┬── panel 5V
          └── ESP32 VIN (5V pin)
PSU GND ──┬── panel GND
          └── ESP32 GND          (common ground is mandatory)
ESP32 GPIO13 ── 330Ω ── [74AHCT125 in/out] ── panel DIN
```

Panel input corner = the end with the DIN arrow. Note which corner it is —
that decides the SERPENTINE/FLIP flags in the sketch.

## Firmware setup

1. Arduino IDE → Boards Manager → install **esp32** (Espressif).
2. Library Manager → install **FastLED**.
3. Open `led_range_board.ino`, set `WIFI_SSID` / `WIFI_PASS`, adjust
   `DATA_PIN` if you wired a different GPIO.
4. Flash. On boot the panel sweeps a teal row across the 13×13 window —
   if the sweep looks interleaved or mirrored, flip `SERPENTINE` /
   `FLIP_X` / `FLIP_Y` until it scans cleanly top-to-bottom.
5. Serial monitor (115200) prints the board's IP. It also announces
   itself as `esp32-range.local`.

## App side

Profile → Dev Tools → **Push Range to LED Board** → enter the board IP
(remembered after first use). The app pushes the current cash range grid.

- Publisher: `lib/services/led_grid_publisher.dart`
- Payload spec lives in both files (169 bytes hex; 3-bit action code +
  5-bit intensity; row-major, ranks AKQJT98765432, pairs on the diagonal,
  suited above, offsuit below). **Change it in both places or not at all.**

## Color legend

| Action | Color |
|---|---|
| Raise | red |
| Call | green |
| Check | cyan |
| Fold | dim blue |
| Mixed (no action ≥60%) | amber |
| No data | off |

Brightness of a cell scales with sample size (capped at 31 hands).

## v1 plan (not built yet)

Replace the LAN POST with Firebase RTDB streaming:
- App writes the same payload to RTDB `led_grid/{uid}` whenever the range
  screen loads or filters change.
- Board authenticates with a dedicated device account
  (Firebase-ESP-Client library, email/password) and holds a stream on the
  path — updates land in ~1s without the app being on the same network.
- RTDB rules: path readable only by the owner and the device account.

Test checklist before calling v0 done:
- [ ] Boot sweep renders clean rows (mapping flags correct)
- [ ] Push from app renders; premium hands (AA/AKs corner) light up red
- [ ] Empty cells stay dark; low-sample cells visibly dimmer
- [ ] Second push updates in place without artifacts
