# Dealer Session Street-by-Street Pot Fix

**Date:** 2026-04-07
**Status:** Confirmed working

---

## Overview

Street-by-street pot amounts (preflopPot, flopPot, turnPot, riverPot) were never saved for dealer-assisted sessions, so hand details showed no per-street pot badges.

---

## Bug: Street Pots Missing in Dealer Session Hand Details

### Problem
After completing a dealer-assisted tournament hand, the hand detail screen showed no street-by-street pot breakdowns (preflop, flop, turn, river badges). Manual logging mode worked correctly.

### Root Cause (Dual Firestore Collection Problem)
The app stores hands in **two separate Firestore collections** for dealer sessions:

1. `poker_sessions/{id}/poker_hands/{handId}` — written by `PokerSessionManager` (includes street pots via `_applyStreetPots()`)
2. `dealer_sessions/{id}/hands/{handId}` — written by `DealerService.completeHand()` (had NO street pot fields)

The hand detail screen (`session_hands_screen.dart`) reads from `DealerService.getSessionHands()` for dealer sessions — which reads from collection #2. Since `DealerService.completeHand()` never wrote street pot fields, they were always absent.

### Fix (2 parts)

**Part A: Add street pot params to `DealerService.completeHand()` (dealer_service.dart)**
Added `preflopPot`, `flopPot`, `turnPot`, `riverPot` optional parameters. Written to the hand document when present and > 0.

**Part B: Pass street pots from game state at all 3 call sites (dealer_table_screen.dart)**
All 3 `DealerService.completeHand()` call sites now pass `_gameState!.streetPots`:
- `_completeHand()` — single winner
- `_completeHandWithChop()` — chopped pot
- `_showMultiPotWinnerDialog()` callback — multi-pot

River pot uses a fallback since `startNewStreet()` doesn't auto-snapshot it:
```dart
riverPot: _gameState!.streetPots[BettingRound.river] ??
    (_gameState!.currentRound == BettingRound.river ? _gameState!.currentPot : null),
```

---

## Related: Unified Street Pot Tracking (same session)

Before this fix, both manual logging and dealer mode used manual `savePotForStreet()` calls scattered across multiple code paths. This was unified:

1. **`PokerGameState.streetPots`** — A `Map<BettingRound, double>` that auto-snapshots the pot in `startNewStreet()` before advancing to the next round. Reset in `startNewHand()`.

2. **`PokerSessionManager._applyStreetPots()`** — Called during `completeCurrentHand()` / `completeCurrentHandWithChop()`, reads from `gameState.streetPots` and sets `HandRecord` fields directly (does NOT call `savePotForStreet()` to avoid overwriting `potAmount`).

3. **Removed all manual `savePotForStreet()` calls** from both `poker_hand_screen.dart` (4 calls) and `dealer_table_screen.dart` (3 calls).

---

## Key Lessons / Bug Prevention

1. **Dual collection awareness**: Dealer sessions write to BOTH `poker_sessions` (via PokerSessionManager) AND `dealer_sessions` (via DealerService). Any new hand field must be written to both.

2. **`savePotForStreet()` has a side effect**: It overwrites `currentHand!.potAmount`. Never call it from `_applyStreetPots()` or any completion path — set fields directly instead.

3. **River pot is never auto-snapshotted**: `startNewStreet()` snapshots the CURRENT round before advancing. Since there's no street after river, river pot must use a fallback to `currentPot` when `currentRound == BettingRound.river`.

4. **Read path determines what users see**: Even if data is written correctly to one collection, the screen must read from the same collection. Always verify which Firestore collection the UI reads from.

---

## Files Modified

| File | Change |
|------|--------|
| `lib/models/poker_game_state.dart` | Added `streetPots` map, auto-snapshot in `startNewStreet()`, reset in `startNewHand()` |
| `lib/models/hand_state_machine.dart` | Added `gameState` param to complete methods, added `_applyStreetPots()` |
| `lib/screens/poker_hand_screen.dart` | Removed 4 manual `savePotForStreet()` calls, pass `gameState` to 9 complete calls |
| `lib/screens/dealer/dealer_table_screen.dart` | Removed 3 manual `savePotForStreet()` calls, pass `gameState` to 4 complete calls, pass street pots to 3 `DealerService.completeHand()` calls |
| `lib/services/dealer_service.dart` | Added `preflopPot/flopPot/turnPot/riverPot` params to `completeHand()` |
