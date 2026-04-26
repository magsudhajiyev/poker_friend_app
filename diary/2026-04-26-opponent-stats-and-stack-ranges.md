# Opponent Stats Overhaul + Stack Range Expansion

**Date**: 2026-04-26

## Problem 1: Broken Opponent VPIP/PFR

Opponent VPIP/PFR stats were always ~100% due to selection bias — we only log hands where hero is involved, so opponents nearly always appear to voluntarily put money in.

### Fix

- **Dropped VPIP/PFR from opponent display** (fields kept in model for backward compat)
- **Added Aggression Frequency**: `aggressionActions / (aggressionActions + passiveActions) * 100` — uses existing legacy action counters (bet/raise = aggression, call/check = passive) which are tracked correctly
- **Added Showdown %**: `showdownCount / handsPlayed * 100` — new `showdownCount` field incremented when opponent doesn't fold and hand reaches showdown
- **Removed auto player-type classification** (TAG/LAG/Fish etc.) — `playerType` always returns `unknown` now. User will manually tag opponents in a future update.
- **Updated AI hand analysis context** to pass `aggressionFreq` and `showdown` instead of `vpip`/`pfr`/`style`

### Files Changed

- `lib/models/opponent_stats.dart` — added `showdownCount`, computed properties, removed classification
- `lib/services/firebase_service.dart` — pass `reachedShowdown` to opponent stat update, track showdown delta
- `lib/services/opponent_stats_service.dart` — handle `showdownDelta` in atomic updates
- `lib/screens/opponent_detail_screen.dart` — replaced VPIP/PFR rows with Aggression Freq + Showdown %
- `lib/screens/hand_actions_screen.dart` — updated AI context, removed `_playStyleCode` helper

## Problem 2: Stack Range Too Coarse + UI Clipping

The 61-100bb range was too wide. Also, the expanded stack ring clipped off-screen when triggered from the table drawer.

### Fix

- **Expanded from 5 to 7 stack ranges**: 1-15, 16-30, 31-60, 61-80, 81-100, 100-150, 150+
- **Added `hideLabels` parameter** to `StackRangeCircle` — hides outside text labels when used in table drawer (prevents clipping)
- **Clamped overlay position** to screen bounds so the expanded ring never clips

### Files Changed

- `lib/models/stack_bucket.dart` — 7 enum values, updated labels/thresholds/midpoints
- `lib/widgets/stack_range_circle.dart` — 7 segments, `hideLabels` support, screen clamping, new colors
- `lib/widgets/table_management_sheet.dart` — passes `hideLabels: true`

## Problem 3: Button Position Sync Bug

Changing dealer button in table drawer caused incorrect position labels (duplicate BBs, wrong SB).

### Root Cause

`table_management_sheet.dart` updated `gameState.buttonPosition` but didn't sync `sessionManager.actualSBSeat`/`actualBBSeat`. Also, position priority check had BB/SB before BTN.

### Fix

- Sync `sessionManager.actualSBSeat`, `actualBBSeat`, and `buttonPosition` when button changes
- Reordered `_getPositionForSeat` to check BTN first

### Notes

- Hot reload does NOT update `static const`/`static final` fields in `CustomPainter` — must hot restart
- Existing opponents with legacy counters will show Aggression Freq immediately; Showdown % starts at 0%
- User stats (play style detector) are completely unaffected — VPIP/PFR work correctly there
