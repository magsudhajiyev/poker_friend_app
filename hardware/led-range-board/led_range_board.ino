// Final Table — physical 13x13 poker range board (v0, LAN transport)
// ESP32 + 16x16 WS2812B panel, using a 13x13 window.
//
// The app POSTs a 338-char hex payload to http://<board-ip>/grid
// (Profile -> Dev Tools -> "Push Range to LED Board").
//
// PAYLOAD SPEC (shared with lib/services/led_grid_publisher.dart — keep in
// sync): 169 cells, row-major, ranks AKQJT98765432; pairs on the diagonal,
// suited above, offsuit below. One byte per cell:
//   high 3 bits: 0 none, 1 raise, 2 call, 3 check, 4 fold, 5 mixed
//   low 5 bits:  intensity 0..31 (hands in sample, capped)
//
// Libraries (Arduino IDE -> Library Manager): FastLED
// Board: any ESP32 dev board (esp32 core by Espressif)

#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <FastLED.h>

// ── CONFIG ──────────────────────────────────────────────────────────
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASS = "YOUR_WIFI_PASSWORD";

#define DATA_PIN 13        // panel DIN through a 330R resistor
#define PANEL_W 16
#define PANEL_H 16
#define GRID 13            // logical grid rendered in the panel's top-left

// Most 16x16 WS2812B panels are serpentine-wired starting top-left.
// If your render looks mirrored or interleaved wrong, flip these.
#define SERPENTINE true
#define FLIP_X false
#define FLIP_Y false

#define MAX_BRIGHTNESS 96  // of 255 — plenty bright, keeps current sane
#define MAX_MILLIAMPS 3000 // FastLED power cap; match your PSU headroom

// ── STATE ───────────────────────────────────────────────────────────
#define NUM_LEDS (PANEL_W * PANEL_H)
CRGB leds[NUM_LEDS];
WebServer server(80);
String lastPayload = "";

// (row, col) of the 13x13 grid -> physical LED index on the panel
uint16_t xy(uint8_t row, uint8_t col) {
  uint8_t x = FLIP_X ? (PANEL_W - 1 - col) : col;
  uint8_t y = FLIP_Y ? (PANEL_H - 1 - row) : row;
  if (SERPENTINE && (y & 1)) {
    return y * PANEL_W + (PANEL_W - 1 - x);
  }
  return y * PANEL_W + x;
}

CRGB actionColor(uint8_t code) {
  switch (code) {
    case 1: return CRGB(255, 30, 30);   // raise  — red
    case 2: return CRGB(30, 255, 60);   // call   — green
    case 3: return CRGB(0, 170, 255);   // check  — cyan
    case 4: return CRGB(35, 35, 190);   // fold   — dim blue
    case 5: return CRGB(255, 140, 0);   // mixed  — amber
    default: return CRGB::Black;        // none
  }
}

bool isHex(const String& s) {
  for (size_t i = 0; i < s.length(); i++) {
    if (!isxdigit((unsigned char)s[i])) return false;
  }
  return true;
}

void renderGrid(const String& hex) {
  FastLED.clear();
  for (int i = 0; i < GRID * GRID; i++) {
    char cell[3] = { hex[i * 2], hex[i * 2 + 1], 0 };
    uint8_t b = (uint8_t)strtol(cell, nullptr, 16);
    uint8_t code = b >> 5;
    uint8_t intensity = b & 0x1F;
    CRGB c = actionColor(code);
    // intensity 0..31 -> perceptible ramp; even 1 hand stays visible
    uint16_t scale = 48 + (uint16_t)intensity * 7;
    if (scale > 255) scale = 255;
    c.nscale8_video((uint8_t)scale);
    leds[xy(i / GRID, i % GRID)] = c;
  }
  FastLED.show();
}

// ── HTTP ────────────────────────────────────────────────────────────
void handleGrid() {
  String body = server.arg("plain");
  body.trim();
  body.toLowerCase();
  if (body.length() != (unsigned)(GRID * GRID * 2) || !isHex(body)) {
    server.send(400, "text/plain", "expected 338 hex chars");
    return;
  }
  lastPayload = body;
  renderGrid(body);
  server.send(200, "text/plain", "ok");
}

void handleStatus() {
  String s = "Final Table LED range board\n";
  s += "ip: " + WiFi.localIP().toString() + "\n";
  s += "rssi: " + String(WiFi.RSSI()) + " dBm\n";
  s += "last frame: " + String(lastPayload.length() ? "yes" : "none") + "\n";
  server.send(200, "text/plain", s);
}

// Boot pattern: sweep the 13x13 window so wiring/mapping is verifiable
// before the first app push.
void bootPattern() {
  for (int row = 0; row < GRID; row++) {
    FastLED.clear();
    for (int col = 0; col < GRID; col++) {
      leds[xy(row, col)] = CRGB(0, 120, 90); // app teal
    }
    FastLED.show();
    delay(40);
  }
  FastLED.clear();
  FastLED.show();
}

// ── SETUP / LOOP ────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  FastLED.addLeds<WS2812B, DATA_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(MAX_BRIGHTNESS);
  FastLED.setMaxPowerInVoltsAndMilliamps(5, MAX_MILLIAMPS);
  bootPattern();

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());

  if (MDNS.begin("esp32-range")) {
    Serial.println("mDNS: esp32-range.local");
  }

  server.on("/grid", HTTP_POST, handleGrid);
  server.on("/", HTTP_GET, handleStatus);
  server.begin();
}

void loop() {
  server.handleClient();
}
