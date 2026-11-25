# 2026-11-25 — Log a hand v2, tracked sessions, live session indicator

Founder device-tested on Android (Xiaomi 23127PN0CG) and confirmed. Spec with all
decisions (D1–D27): `docs/features/single-hand-setup-v2.md` (docs/ is gitignored).

## What exists now
- **Log a hand v2** (flag `single_hand_v2`): full-screen setup — game pill sheet with
  vertical blinds/players wheels + "+ Custom blinds", mini table seat picker (follows
  the finger), `StackDragControl` (snapped vertical drag, haptics, keypad), optional
  cards. In hand: villain "100 BB?" badge → relative stack sheet; villain all-in with a
  default stack opens the sheet first. Random stack spread removed; per-seat
  `stackSources` (set/default, SQLite v23). After saving: a simple "Hand saved" dialog
  (Log another / Done); a new hand group must be named there (no automatic names).
- **Track a session** (flag `tracked_session`): name, type, buy-in. Hub button is always
  "Log a hand" → hands saved INSIDE the session (`sessionType: 'tracked'`), never in
  hand stats, never touching the session money. Ends through the normal end sheet.
- **One running session**: `SessionStartGate` (data first, then the record) blocks
  every new session at the mode card AND at Start. No bypass.
- **Live session**: Android ongoing notification (system chronometer, no money,
  "Log a hand" / "Open session"), Home running bar, "Still playing?" after 24 h,
  re-post on launch. iOS Live Activity is phase 2 (not built).
- **Fair play while a session runs**: AI analysis, share and export locked (tap shows
  an info snackbar), FLAG_SECURE on Android, iOS blurs the action list and covers the
  app during recording.
- Hand delete (stat-free hands only), bigger seat plates, stronger turn glow, compact
  Choose mode rows; tour Phase 1 Skip pill moved to the top and bubble above the row.

## Bugs found on the device and their causes
- **Players sheet could not scroll**: a scroll view nested inside `AppSheet`'s scroll
  view. Fix: one scroll; later the sheet became non-scrollable with wheels.
- **A second session "ditched" the first**: the guard trusted only the SharedPreferences
  record; a full session had no record until its table opened; `start()` replaced a
  running record silently. Fix: `SessionStartGate` reads SQLite first, rebuilds missing
  records, `start()` never replaces another running record, gate runs before setup.
- **Resume bar opened the hub N times**: awaited Firestore before the push and no
  single-flight. Fix: `SessionNavigation` guard + push first, load inside the screen.
- **Choose mode sheet had big gaps**: content inside a `Center` stretched to the cap.

## Gotchas
- Flutter MUST be 3.38.10 via FVM (`fvm flutter …`). Homebrew had installed 3.50.1,
  which asked for Gradle 9.3.1 and rewrote pubspec.lock / registrants /
  gradle.properties. `android/local.properties` `flutter.sdk` decides which SDK the
  IDE build uses.
- A full session older than 24 h with no endTime is treated as abandoned (never
  blocks, not in the Home bar); tracked sessions block at any age.
