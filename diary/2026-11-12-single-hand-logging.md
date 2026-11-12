# 2026-11-12 — "Log a hand" (single-hand logging) + tour/paywall analytics

Ships in 2.2.0+28 behind the `single_hand` flag (admin_only; switch to `on`
when the build is live in both stores). Plan and decisions:
`docs/features/single-hand-logging.md`. Founder tested on device during the
build (setup sheet, wheels, nickname, opponents, stacks, share replay).

## What it is

A third card under + : log ONE hand fast, no session. Setup sheet (full
height) → throw-away hand table (`PokerHandScreen` single mode, built on the
recall-mode machinery) → result sheet (star, notes, tags, View hand / Log
another / Done).

## Storage decision

Hands go into a **hand group**: a lightweight session doc in `poker_sessions`
with `sessionType: 'hand_group'`, so every hand reader (details, AI analysis,
share, exports, session hands screen) works unchanged and no Firestore rule
changed. A new hand joins the latest group when its last hand is < 12 h old,
same game type, and (cash only) same blinds, and the group is under the tier
hand cap; otherwise a new group starts. `handNumber` = group `totalHands + 1`.
Group ids are client-generated (`collection.doc()`), cloud writes time out
after 4 s without error (offline-safe). SQLite schema **v22** adds
`sessions.sessionType`.

Single hands do **not** touch hero stats, opponent stats, the range grid, the
Leak Detector, bankroll, `session_results` or play time (`skipStats: true`, no
`endSession`). Reason: players log hands they picked, so frequency stats would
be biased. `getAllSessions` / `getUserSessions` hide hand groups unless called
with `includeHandGroups: true` — Session History, the opponent hand list and
the opponent shown-cards range pass it; stats aggregates do not.

## Bugs found and fixed during the build

- **Opponent lost on save**: the save built `playerNames` from the setup only
  (nickname + positions) and ignored the live table. Now
  `SingleHandService.mergeNames` merges `sessionManager.playerNames` /
  `playerIds` (a live name wins unless empty, `Player N` or a bare position).
- **Hero nickname missing on the table**: the snapshot carried no names. The
  hero seat now gets `DisplayIdentityService.cachedDisplayIdentity`, villains
  their position label; the saved hand matches.
- **Huge stacks (10,400,000 at 100/200)**: the stack field was always read as
  BB; the founder typed his tournament stack in chips (52,000). The field now
  has a unit (tournament Chips|BB, default Chips; cash $|BB, default BB),
  a live conversion line and a guard above 1,000 BB / below 1 BB with a
  one-tap unit fix. `stackBB` stays the stored truth.
- **Tags stored translated**: now stored as English values like
  `HandReviewDialog` ('Bluff', 'Hero Call', …) and shown translated.
- **`hand_saved` marked single hands `is_tutorial`** (because of `skipStats`):
  now `mode: single`.
- **Wheel reported every item during a fling** (re-ran the group lookup,
  could open "Custom…" mid-scroll): `AppWheelPicker` reports on scroll end.
- **Magnified wheel labels clipped**: labels are fitted to
  `1 / magnification` of the column width.

The shared-hand replay "wrong order" report was checked against the real
`shared_hands/5dPnQe5J` doc and the web `buildReplay`: data and replay were
correct (the founder confirmed). No change.

## New pieces

- `AppWheelPicker<T>` (design system, `pickers/`): onboarding-style wheel.
- `BlindLevel` lists per game type + "Custom…" (empty editor, hints).
- Stack spread Same / Near (±10%) / Similar (±25%): villains rolled once at
  Start, hero always exactly X, whole BB, ≥ 1 BB.
- Session History: hand-group rows with a "Hands" badge, no P/L.

## Tour / paywall analytics (same release)

`tour_completed` fired only on a full finish; both skip paths opened the
paywall with no event, and the post-tour paywall + hard gate built
`PaywallScreen` directly so `paywall_opened` (only in `show()`) never fired.
Now: `tour_started` (in `OnboardingState.start()`, not on replay),
`tour_skipped {phase}` on both skip paths, and `paywall_opened` moved to
`PaywallScreen.initState` with `feature` = `post_tour` / `tour_skipped` /
`hard_gate` / `profile_promo` / `settings` / `notification` / `drawer` for
direct constructions. Tour behaviour unchanged.

## Known gaps / later

- Not on Home, Statistics or Leak Detector by design; a "Logged hands" Home
  entry was proposed, not built.
- "Add to the current session", move a hand between groups, rename a group,
  date picker for past hands, draft autosave: later.
- Web dashboard does not know `hand_group` yet (shows them as sessions).
