# Video Script — "Daily Challenge" Feature Reel

**Format:** vertical 9:16 (1080×1920), Instagram Reels / TikTok / YouTube Shorts
**Target length:** ~40 seconds
**Audience:** both serious grinders AND beginners — the opening explicitly bridges the two
**Tone:** confident, warm, a little playful once the coaches appear

All referenced assets are in `marketing/reel-assets/` (AI-generated scenes +
real coach voice lines) and `assets/mascots/` (coach expression stills).
A previous machine-made cut for pacing reference: `marketing/daily-challenge-reel.mp4`.

---

## Beat 1 — Who Final Table is for (0:00 – 0:08)

**Visual:** App in real use — quick cuts of actual screen recordings:
logging a hand on the table screen, the statistics screen, the range grid.
Open on the app logo (`assets/logo.png`) for half a beat.

**VO (narrator):**
> "Final Table is the hand-logging tool serious players use to find their
> leaks. But here's the thing — you don't have to be a pro to start."

**On-screen text:**
- `BUILT FOR SERIOUS PLAYERS` (beat 1)
- `MADE FOR EVERYONE` (beat 2 — lands with the VO turn)

**Direction:** the first phrase sits over the "pro" footage (stats, range
grid); the second lands as the footage cuts to something simple and
friendly (home screen / a single tap). The contrast IS the message.

---

## Beat 2 — Introducing Daily Challenges (0:08 – 0:18)

**Visual:** `scene_poker_table.mp4` (cinematic table, cards sliding) →
screen recording of the Daily Challenge intro screen and one real decision
being played (tap raise → coach feedback card pops up).

**VO (narrator):**
> "That's why we built the Daily Challenge. Five real poker decisions,
> every day. Everyone in the world gets the same cards — and a coach
> grades every move you make, the moment you make it."

**On-screen text (staggered, one line per sentence):**
- `NEW: DAILY CHALLENGE`
- `5 decisions. Every day.`
- `Same cards as everyone.`
- `A coach grades every move.`

**Direction:** when the VO says "grades every move", show the in-app
moment: verdict badge popping (BEST MOVE) + the mascot bouncing. That's
the chess.com-style hook — don't rush it.

---

## Beat 3 — Meet the coaches (0:18 – 0:33)

Kicker text stays up for the whole beat: `MEET YOUR COACHES`

Each coach gets ~5s: their animated scene, name card, and their REAL
in-app voice line (these exact audio files play in the app — use them,
don't re-record):

**3a — Duke** (`scene_duke.mp4` + `vo_duke.mp3`)
- Name card: `DUKE — Old-school Vegas grinder`
- Voice line: *"Name's Duke. Forty years at the felt. Show me you can fold, kid."*

**3b — Prof. Vega** (`scene_vega.mp4` + `vo_vega.mp3`)
- Name card: `PROF. VEGA — The GTO theorist`
- Voice line: *"Professor Vega. We will proceed by equilibrium. Deviations will be noted."*

**3c — Nova** (`scene_nova.mp4` + `vo_nova.mp3`)
- Name card: `NOVA — Your hype coach`
- Voice line: *"Nova here! Five spots, full focus. Bring your A-game and let's make it a perfect day!"*

**Direction:** no narrator here — let the characters carry it. Duck the
music under each voice line. If a line runs past its clip, let it bleed
into the next cut rather than speeding up the audio.

---

## Beat 4 — Close / CTA (0:33 – 0:40)

**Visual:** `scene_gold_chip.mp4` (spinning golden chip) for 2–3s, then
the branded end card: app logo, title, store badges, URL. (Static
reference: the last 5 seconds of `daily-challenge-reel.mp4`.)

**VO (narrator):**
> "Your first challenge is waiting. Final Table — download it free."

**On-screen text / end card:**
- App icon (`assets/logo.png`)
- `DAILY CHALLENGE` / `FINAL TABLE`
- `Train daily. Beat the field.`
- **App Store + Google Play badges** (use the official ones:
  [Apple badge](https://developer.apple.com/app-store/marketing/guidelines/),
  [Google badge generator](https://play.google.com/intl/en_us/badges/))
- `finaltable.io`

---

## Production notes

- **Music:** energetic but not frantic; duck −12dB under every voice
  line. If posting to Reels/TikTok, consider swapping in a trending
  in-platform audio at low volume for reach.
- **Captions:** burn subtitles for the narrator VO (most viewers watch
  muted) — but NOT over the coach lines if the name cards are up; the
  cards already carry the information.
- **Coach voices — generating NEW lines yourself:** the voices are STOCK
  voices from the ElevenLabs public library (not custom clones), so you
  can reproduce them exactly with your own free elevenlabs.io account
  (free tier ≈ 10k chars/month, plenty for video lines). In
  Text-to-Speech, pick the voice and settings below, type the line,
  download the MP3:

  | Coach | ElevenLabs voice | Stability | Similarity | Model |
  |---|---|---|---|---|
  | Duke | Bill (old, wise American) | 0.45 | 0.8 | Flash v2.5 |
  | Prof. Vega | George (British storyteller) | 0.55 | 0.8 | Flash v2.5 |
  | Nova | Laura (enthusiast, quirky) | 0.30 | 0.8 | Flash v2.5 |

  Flash v2.5 matches the app's output exactly; "Multilingual v2" is a
  slightly richer alternative that's fine for marketing. Alternatively,
  send the lines to Magsud/Claude and get MP3s back through the app's
  own pipeline.
- **Mascot stills** for thumbnails/frames: `assets/mascots/`
  (`{duke=grinder, vega=professor, nova}_{idle,happy,ok,upset}.png`,
  transparent 400px).
- **Screen recordings:** capture on a physical device with the
  `daily_challenge` flag on; the "Reset today (testing)" link on the
  results screen lets you replay the same challenge for multiple takes.
  Remember the daily spots are date-seeded — record all takes the same
  day for continuity.
- **Legal:** coaches are original characters (never real players); the
  coach voices are licensed ElevenLabs stock voices — fine for ads.
