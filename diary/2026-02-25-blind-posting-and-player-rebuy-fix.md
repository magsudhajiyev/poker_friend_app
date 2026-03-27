# Fix: Blind Posting Timing and Player Rebuy Issues

**Date:** 2026-02-25

## Problems

### Issue 1: Blind Posting with Stale Player List
When a player was added or removed between hands, the blinds were calculated with the OLD player list instead of the CURRENT list.

**Root Cause:**
- `startNewHand()` (in `poker_game_state.dart`) was calling `initializePot()` to post blinds
- This happened at the END of the previous hand, BEFORE any player changes
- When dealer clicked "Start New Hand", `_startNewHand()` (in `dealer_table_screen.dart`) skipped `initializePot()` thinking it was already done
- Result: Newly added players weren't included in blind rotation

### Issue 2: Re-added Player Skipped in Action
When a busted player was re-added to the table, they were skipped in the action order and the hand didn't complete properly (BB showed "call -10").

**Root Cause:**
- When a player busts and is removed, `setPlayerActive(seatNumber, false)` is called
- But their `hasFolded` flag stays `true` from their last hand
- When re-added via `setPlayerActive(seatNumber, true)`, only `isActive` was set
- `_getNextActivePlayer()` skips players with `hasFolded=true`
- Result: Re-added player was skipped because their `hasFolded` was still true

---

## Solution

### Fix 1: Move Blind Posting to _startNewHand()

**File:** `lib/models/poker_game_state.dart`

Removed `initializePot()` call from `startNewHand()`. Blinds are now ONLY posted when the dealer clicks "Start New Hand".

**File:** `lib/screens/dealer/dealer_table_screen.dart`

Now calls `initializePot()` for ALL hands (first and subsequent) in `_startNewHand()`.

### Fix 2: Reset Player State on Activation

**File:** `lib/models/poker_game_state.dart`

Modified `setPlayerActive()` to reset hand state when a player is activated:

```dart
void setPlayerActive(int playerId, bool isActive) {
  PlayerState player = _getPlayer(playerId);
  player.isActive = isActive;

  // When activating a player (e.g., adding them back after busting),
  // reset their hand state so they can participate in the next hand
  if (isActive) {
    player.hasFolded = false;
    player.hasActed = false;
    player.hasCalledCurrentBet = false;
    player.isAllIn = false;
    player.lastAction = PlayerAction.none;
    player.betThisRound = 0.0;
    player.totalContribution = 0.0;
  }
}
```

---

## Files Modified

| File | Change |
|------|--------|
| `lib/models/poker_game_state.dart` | Removed `initializePot()` from `startNewHand()`, added state reset in `setPlayerActive()` |
| `lib/screens/dealer/dealer_table_screen.dart` | Always call `initializePot()` in `_startNewHand()` for all hands |

---

## Hand Visibility for Busted Players

Also verified that hand visibility filtering works correctly:
- When a player busts, `markParticipantLeft()` records their `leftAtHand`
- When they rejoin, `addSessionParticipant()` creates a NEW participation period
- `SessionHandsScreen` filters hands based on participation periods
- Busted player only sees hands from when they were at the table

---

## Verification

1. Start dealer session with 9 players
2. Complete hand where one player busts
3. Verify busted player doesn't see subsequent hands in their Session History
4. Add busted player back to the table
5. Start new hand
6. Verify:
   - Re-added player is included in action rotation (not skipped)
   - Blinds are posted correctly with updated positions
   - Hand completes normally when everyone folds
   - No "call -10" bug
