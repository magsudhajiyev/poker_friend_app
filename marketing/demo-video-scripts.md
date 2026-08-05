# Final Table — Demo Video Scripts

*Created 2026-07-29. Shot-by-shot scripts for screen-recorded demos. Record on a real device in release mode, English locale, with a seeded account that has 100+ hands so stats/charts look alive (empty-state screens kill demos). Before recording club footage, smoke-test club flows first — they haven't been re-verified since the launch-night Firestore rules changes (ROADMAP item 3).*

**General rules**
- 9:16 vertical, 60fps screen capture; keep every clip under its target length — cut ruthlessly.
- No audio narration dependency: every video must work muted with text overlays.
- Never show: debug menus, admin screens, real user names/emails, the forgot-password flow.
- End every video on the same outro frame: app icon + "Final Table — free on Google Play."

---

## Video 1 — "Your first hand" (30s, the onboarding hook)

**Goal:** show it takes under a minute to log a real hand.

| # | Shot | Screen action | Overlay text |
|---|------|---------------|--------------|
| 1 | 0–3s | App opens, logo animation → home screen | "Poker tracker that logs *every hand*" |
| 2 | 3–7s | Tap + FAB → mode selection → Full Logging | "Start a session" |
| 3 | 7–12s | Seat setup: pick your seat at the table, blinds visible | "Pick your seat" |
| 4 | 12–20s | Log a quick hand: raise → call → flop cards entered → bet → fold, chips animate to winner | "Tap through the action" |
| 5 | 20–25s | Hole cards entered, hand saved, stats tick up | "Your stats update instantly" |
| 6 | 25–30s | Outro frame | "Final Table — free on Google Play" |

**Note:** record several takes of shot 4 — the chip animation is the money shot.

---

## Video 2 — "The dealer just talks" (25s, voice logging)

**Goal:** the wow moment. Real audio matters here — this is the ONE video where sound is the point (still subtitle everything).

| # | Shot | Screen action | Overlay text |
|---|------|---------------|--------------|
| 1 | 0–3s | Dealer table screen, mic indicator live | "Hands-free hand logging" |
| 2 | 3–15s | Dealer voice: "Seat 3 raises to 12… seat 5 calls… flop ace of spades, king of hearts, queen of diamonds" — actions appear on screen as spoken | Subtitles of the speech |
| 3 | 15–21s | Cut to a second phone: same hand appearing live on a player's screen | "Every player watches live" |
| 4 | 21–25s | Outro frame | "Final Table — free on Google Play" |

**Note:** rehearse the exact phrases against the parser first; script only utterances that recognize reliably. Quiet room, phone 30–50cm from speaker.

---

## Video 3 — "What kind of player are you?" (20s, stats + play style)

**Goal:** the identity hook — drives the strongest CTA.

| # | Shot | Screen action | Overlay text |
|---|------|---------------|--------------|
| 1 | 0–4s | Statistics screen, scroll through VPIP/PFR/3-bet with position breakdown | "Your real stats. From your real hands." |
| 2 | 4–10s | Slow scroll to play-style classification | "After 50 hands, it tells you the truth" |
| 3 | 10–15s | Play-style reveal (seeded account should show something spicy, e.g. LAG) | "So… TAG or Calling Station?" |
| 4 | 15–20s | Outro frame | "Find out. Free on Google Play." |

---

## Video 4 — "The night, in one card" (15s, session summary)

**Goal:** show the share loop; shortest video, highest rewatch.

| # | Shot | Screen action | Overlay text |
|---|------|---------------|--------------|
| 1 | 0–4s | End session → cash-out sheet → confirm | "Session over" |
| 2 | 4–10s | Summary card animates in: P/L, duration, biggest pot, best/worst hand | "Your whole night, one card" |
| 3 | 10–13s | Tap share → share sheet opens | "Brag responsibly" |
| 4 | 13–15s | Outro frame | "Final Table — free on Google Play" |

---

## Video 5 — "See your range" (20s, range grid + AI review)

**Goal:** the study-tools pitch for the serious player.

| # | Shot | Screen action | Overlay text |
|---|------|---------------|--------------|
| 1 | 0–6s | Range grid screen, 13×13 grid colored by frequency | "Every hand you've played. One picture." |
| 2 | 6–12s | Tap a hand → hand history → AI analysis panel | "AI reviews it street by street" |
| 3 | 12–17s | Scroll AI analysis text (in English; flash the language picker for 1s) | "In your language. At your level." |
| 4 | 17–20s | Outro frame | "Final Table — free on Google Play" |

---

## Video 6 — "Club night" (40s, the B2B one)

**Goal:** home-game hosts and club owners. Needs 2–3 phones + a TV/monitor. **Smoke-test club flows before shooting.**

| # | Shot | Screen action | Overlay text |
|---|------|---------------|--------------|
| 1 | 0–5s | Real table, physical cards, phones out (lifestyle shot, not screen cap) | "Your home game. Upgraded." |
| 2 | 5–12s | Player scans table QR → seat confirmed on their phone | "Scan. Sit. Play." |
| 3 | 12–22s | Dealer logs a hand (voice or taps); cut between dealer phone and a player phone updating live | "One dealer logs. Everyone follows." |
| 4 | 22–32s | TV shows the full-screen live leaderboard; a knockout updates the rankings | "Live rankings on the big screen" |
| 5 | 32–37s | Final standings screen with trophies | "One subscription runs the whole club" |
| 6 | 37–40s | Outro frame | "Final Table — free on Google Play" |

---

## Shot checklist before any recording session

- [ ] Release build, seeded demo account (100+ hands, named sessions, a tournament with a placement)
- [ ] Demo opponent names are fictional ("Mike R.", "Anna K." — no real users)
- [ ] Device language English, clock set to a clean time, notifications off, full battery icon
- [ ] Club flows smoke-tested (ROADMAP item 3) before Video 6
- [ ] Voice phrases pre-tested against the parser before Video 2
