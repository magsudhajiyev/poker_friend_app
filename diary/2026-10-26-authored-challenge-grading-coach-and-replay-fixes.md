# 2026-10-26 — Authored Daily Challenge: grading, coach-text, position & replay fixes

A round of on-device bug fixes found while playing the authored (solver
game-tree) Daily Challenge days, plus the data to test them. All on `main`,
pushed (see "Commit").

## 1. Grading: hand-unreachable nodes misgraded as LEAK (HIGH)

**Symptom:** a KQs river decision graded the player's FOLD as a leak AND the
coach said "you should've folded" — a contradiction, when the player folded.

**Cause:** the solver only lists hands that can REACH a node. On a deep reroute
line the hero hand (KQs) had taken an earlier action at ~0%, so it was absent
from that river node's frequency map. The grader read `freqOf(...) = 0` for
every action → the fold graded as freq=0 → LEAK; and `dominantHeroAction`
degenerated to the first action (fold) → "best = fold" → the contradictory
message.

**Fix:** `AuthoredTreeWalker.advanceVillains()` now ENDS the hand when it lands
on a hero node where the hero hand has no frequency (`TreeNode.hasHeroFreq`).
An unreachable node is never presented as a decision — it simply doesn't appear.
(This is exactly what the exporter recommended; the solver sheets even emit a
"not in range" explanation for these rows.) Test:
`authored_tree_walker_test.dart` → "ends the hand at a hero node the hero hand
cannot reach".

## 2. Coach text (`authored_spot_grader.dart`, `authored_situation.dart`, `coach_persona.dart`)

Four phrasing bugs, all reported on device:

- **"You've flopped {hand}" / "flopped two overcards"** — the situation
  narrator announced non-made hands (overcards, bare draws) and restated an
  unimproved pocket pair as "flopped". Now it only narrates a genuine MADE hand
  that connected with the board. Overpairs say "You have an overpair, nines"
  (not "flopped" — you already held the pair); underpairs, overcards and
  draw-only are suppressed. Added `HandRead.made` + `.overpair`.
- **"bet" vs "raise"** — putting chips in with nothing to call is a BET; over a
  villain's bet it's a RAISE. The grader now picks the verb from
  `toCallBB > 0` (preflop opens stay "raise"). Fixed in `_label`/`_noun` via
  an `aggroIsRaise` flag.
- **"raise edges it" when the player bet** — the coach persona's `{action}`
  template substituted the raw wire action (always "raise"). Added
  `DrillGradeResult.recommendedWord` (street-aware, set by the authored grader
  to `bestNoun`); the persona now uses it, so a flop bet reads "bet", never
  "raise".
- **"bet edges it" when the player bet AND bet is best** — an OK verdict where
  the hero picked the solver's TOP action (a thin 59% mix) used
  "but {best} is the bigger share" wording and a hedging lead, implying a better
  line that doesn't exist. Now: the reason affirms ("A valid play — the bet is
  the solver's most frequent choice (59%); it mixes other lines too, so this is
  a close spot") and the persona uses the praise ("correct") leads. The GOOD
  badge stays accurate (59% is a genuine mix, below the 65% BEST band).

## 3. Position label mismatch — villain seat shown as folded (HIGH)

**Symptom:** on a BTN-vs-UTG+1 spot the UTG+1 seat rendered as "folded" while
the hand continued against it.

**Cause:** solver sheets title positions as `UTG1`/`UTG2`; the app's seat map
uses `UTG+1`/`UTG+2`. `_villainVisual` couldn't find "UTG1" → fell back to the
BTN seat, and the real UTG+1 seat was marked folded.

**Fix:** `authored_challenge_screen.dart` added `_normalizePos()` (UTG1→UTG+1,
UTG2→UTG+2, MP/MP1→LJ, MP2→HJ, EP→UTG, …) applied to hero AND villain
positions — fixes every already-uploaded spot at render time, no re-upload
needed. Also `build_tree.js` normalizes the OUTPUT heroPosition/villainPosition
(keeping the raw sheet labels internally for actor/history matching) so future
uploads are canonical.

## 4. Replay UX (`daily_replay_screen.dart`, `daily_challenge_screen.dart`)

- **"Past challenges" button vanished after finishing today's challenge** — it
  was only on the intro view, not the results view. Added it to the results
  view too.
- **Replay intro "middle screen" on the way back** — opening a past day with no
  prior result auto-starts the run (no intro teaser; a spinner while loading);
  abandoning the run pops straight back to the calendar instead of landing on
  the intro. Removed the now-dead `_intro`. Plus a re-entrancy guard on
  "Replay again".

## 5. Data populated for testing

- **2026-10-25** scheduled with 5 full spots (43s/JTo/ATs/98s/KK) — the newer
  13-column sheet format with hero-hand columns.
- **2026-10-26** 4 clean spots (A9s/TT/A5s/KQs), re-imported with the exporter's
  back-filled hero columns; the 5th (A4s · 5s3c2s) was dropped for genuine
  river-range gaps — the exporter is producing a replacement (strict rule:
  5 spots/day). See `tool/gto_export/DATA-QUALITY-NOTES.md`.
- **Why 24/25 showed the generic 99 spot:** unscheduled days fall back to the
  bundled `assets/authored/days.json` `default` (`lj-btn-ts9c4d-99`, a testing
  bridge). 25th is now scheduled; 24th still falls back until populated. The
  `default` must be removed before GA so unscheduled days play the RNG drill.

## Verification
- `flutter analyze`: 0 errors. `flutter gen-l10n`: 0 untranslated.
- `flutter test`: all pass (incl. the new walker-unreachable test + the
  coach/grader/situation suites).
- On-device (Android): all four reported coach-text issues, the position bug,
  and the two replay-UX issues confirmed fixed.

## Still open
- Exporter to deliver the 5th 2026-10-26 spot (replacement for A4s).
- Remove the `days.json` `default` testing bridge before GA.
- `validateLeaderboardEntry` CF + authored Firestore rules were already
  deployed (verified live) — the earlier "not deployed" note is stale.
