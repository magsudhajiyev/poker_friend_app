# 2026-10-25 — Daily Challenge replays, hard-paywall value-prop screen, onboarding + leaderboard fixes

A broad session on the hard-paywall / Daily Challenge monetization funnel. Everything
below is on `main` (uncommitted at time of writing → see "Commit" at the end).

## 1. Daily Challenge Replays (NEW feature)

Replay a PAST day's challenge for unranked practice. Tier-gated per the
2026-10-22 pricing decision: **free = no replays, Pro = last 15 days,
Elite/Club = unlimited** (back to the challenge epoch, 2026-10-14).

**Design decisions (user-confirmed):**
- Replays are **fully unranked & non-counting** — they NEVER write to the ranked
  store, the streak, or the leaderboard. This is both a product choice and a
  correctness requirement: streaks are *derived* from saved ranked results
  (`computeStreaks`), so back-dating a result into the ranked store would
  retroactively corrupt the streak.
- Results ARE persisted — to a **separate** store so the calendar remembers them
  across app restarts without touching streaks. **Latest replay wins** when a
  day has both a ranked result and a replay.
- Entry point: a **"Past challenges"** button on the Daily Challenge intro
  (next to Leaderboard). The picker is a **month calendar grid**.
- No extra save-gating: if your tier lets you replay a day and you do, it's saved.

**Files (all new unless noted):**
- `lib/services/daily_replay_limits.dart` — pure tier window logic:
  `replayWindowDays()` (0 / 15 / null), `earliestReplayDay(today)` (epoch-clamped),
  `isReplayable(day, today)`, `isLockedByTier(day, today)`.
- `lib/screens/training/daily_challenge_calendar_screen.dart` — month grid; day
  cells reflect played/replayable/locked/out-of-range; tier-window banner; locked
  days open the paywall (preselected tier); nav arrows **hidden** (not greyed) at
  the true month boundary so a single-month archive doesn't read as broken;
  rebuilds on `premiumStatusStream` so a purchase unlocks older days live.
- `lib/screens/training/daily_replay_screen.dart` — plays the exact spots for the
  chosen date (construction is a pure function of the date, so an old day
  reproduces precisely), grades identically, shows the breakdown, writes ONLY to
  `DailyReplayStore`. Auto-starts the run when there's no prior result (skips the
  intro); shows the breakdown when a result exists; returns its result on pop so
  the calendar can cache it.
- `lib/services/daily_challenge_store.dart` (modified) — new **`DailyReplayStore`**
  (separate SharedPreferences key `daily_replay_results`) + a shared
  **`DailyChallengeResult.build(...)`** factory so the normal play path and the
  replay path assemble results identically (one source of truth).
- `lib/widgets/daily_result_breakdown.dart` — extracted the collapsible
  per-hand, street-by-street results view (hero card faces, board faces, verdict
  dots, coach line) so the replay results render IDENTICALLY to the main DC
  results. Faithful extraction of the shipped `_handSection`/`_spotRow`/
  `_miniCards`/`_cardList`/`_authoredActionLine`.
- Tests: `test/services/daily_replay_limits_test.dart` (16, tier boundaries),
  `test/services/daily_replay_store_test.dart` (4, incl. the separation guarantee
  that replays never land in the ranked store).

**Pure client-side — no Firestore collections, no rules, no deploy.**

## 2. Hard-paywall value-proposition screen

`lib/screens/value_proposition_screen.dart` (NEW) — a "How Does the Free Trial
Work?" explainer shown after the user picks a plan on the paywall and taps
Continue, BEFORE the purchase. Timeline (Today → Day 2-N → Day N), cancel-steps
card (platform-aware), "No Payment Today / Secured with …", big **"Try it for
free"** CTA. The trial length + price are read from the selected **store
product** (never hardcoded); the steps fade/slide in top→bottom. Container
hugs its content (removing an `alignment` that was forcing it to the maxHeight).
Wired in `paywall_screen.dart`: Continue → value-prop → `_startPurchase()` (real
store sheet). Debug-only trial fallback renders the full design on a sideload.

## 3. Daily Challenge on the plan cards

Added a replay-focused feature line to Pro ("Daily Challenge + replay last 15
days") and Elite ("Daily Challenge + unlimited replays"); Club inherits via
"Everything in Elite".

## 4. Hard-paywall gate race fix

`lib/screens/hard_paywall_gate.dart` — the gate read the "first run complete"
flag once at mount; on the fresh-signup→Home path that read lost the race
(stale Firestore cache), latched `false`, and never re-read → the gate stayed
open forever. Now it **re-reads reactively** (on tour-state/subscription
changes) until it resolves true.

## 5. Onboarding fixes

- **Username always asked.** `UsernameService.hasCompletedUsernameSetup()` used
  to return `true` (skip the step) when the user doc was null OR the
  `hasSetUsername` field was simply absent — which also caught brand-new users
  (a fresh doc lacks the field). New logic: "done" only if there's a real
  `username` value OR `hasSetUsername == true`; otherwise ask. Legacy users
  (who have usernames) and intentional skippers (flag set) are unaffected; the
  lenient `true`-on-read-error is preserved so established users aren't blocked
  on flaky networks.
- **Demo → info screen.** After the onboarding demo spot the last authored-hand
  button now says **"Done"** (via a new `lastHandLabel` param on
  `AuthoredChallengeScreen`/`AuthoredDayRunner`, default "See result"), and a
  NEW final onboarding step — `lib/screens/onboarding/daily_challenge_info_step.dart`
  ("Your daily poker workout": 5 spots/day, experience-tuned, coaches explain
  the lines) — runs before Home + the in-app tour.

## 6. Leaderboard username prompt

`_submitToLeaderboard` (daily_challenge_screen) now opens
`UsernameSetupScreen(leaderboardContext: true)` which shows an info note
("required for the leaderboard; skip → your real name is used") and a skippable
button. Skip → submit with the display-name fallback (`_leaderboardFallbackName`
= displayName, else `Player####`). Once skipped (`hasCompletedUsernameSetup`
true), it stops re-prompting and just uses the real name.

## 7. Coach container shrink-to-text

`authored_challenge_screen.dart` — the feedback/pre-decision coach card had a
big empty gap for short text. Root cause: `alignment` on a `Container` with a
`maxHeight` makes it **expand to the max** to position its child. Removed the
`alignment` (and the mascot-height `minHeight`); the card now hugs its content,
the mascot overflows top & bottom freely, and long text still scrolls at the
26% cap.

## Verification
- `flutter analyze`: **0 errors**.
- `flutter gen-l10n`: **0 untranslated** (all 11 locales; 40+ new keys).
- `flutter test`: **930 pass** (incl. 16 replay-limits + 4 replay-store + all
  existing DC/subscription/onboarding suites).
- Pre-commit review (fork): no blockers; confirmed replays never touch the
  ranked store/streak/leaderboard, `build()` index alignment is byte-identical
  to the shipped original, username logic spares returning users. Four minor
  items raised; three fixed (replay re-entrancy guard, sticky leaderboard skip,
  stale comment), one accepted as-is.
- On-device (Android, Xiaomi houji): all flows exercised during development.

## Notes / still open
- iOS simulator can't run the app (ML Kit via `mobile_scanner` ships no
  arm64-simulator slice; Xcode 27 dropped x86_64 sim). Test iOS on a device /
  TestFlight. Unrelated to this work.
- The trial-badge investigation concluded the app code is correct; trials not
  showing was a Play/RevenueCat offer-config + build-recognition issue (needs a
  Play-tester build on a License-Tester account) — not a code bug.
