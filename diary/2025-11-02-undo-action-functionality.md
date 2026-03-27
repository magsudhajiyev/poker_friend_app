# Undo Action Functionality Implementation

**Date**: November 2, 2025
**Status**: ✅ Completed and Tested
**Feature**: Roll back action button with full state restoration

## Summary

Implemented comprehensive undo functionality for hand logging that allows users to roll back mistaken actions during hand entry. The feature properly restores all game state including player stacks, pot amounts, and betting rounds.

## User Request

"We need to have roll back action button during hand logging. Problem is that sometimes during hand logging user can make mistake like a player checks but user logs it as fold. For this cases we must have a button and each click to that button must roll the action one state back."

## Implementation Details

### 1. UI Component (poker_hand_screen.dart:1179-1195)

**Added "Undo Last Action" Button:**
- Orange button positioned after "End Street Betting" button
- Only visible when undo is available
- Icon: undo_outlined
- Calls `_undoLastAction()` on press

### 2. Undo Validation (poker_hand_screen.dart:3375-3404)

**Method: `_canUndoLastAction()`**

Checks if undo is allowed:
- ✅ Hand must be in progress (not completed)
- ✅ Betting round must not be complete
- ✅ Must have non-blind actions to undo
- ❌ Cannot undo blind posts (preserves game integrity)

### 3. Core Undo Logic (poker_hand_screen.dart:3406-3598)

**Method: `_undoLastAction()`**

**Action-Specific Restoration:**

**Fold:**
- Restore `hasFolded = false`
- Reset `hasActed` and `lastAction`

**Check:**
- Reset action state
- Recalculate call status based on remaining actions

**Call:**
- Calculate `previousBetThisRound` from prior actions
- Calculate `additionalAmount = amount - previousBetThisRound`
- Restore stack: `+= additionalAmount` (not total amount!)
- Restore pot: `-= additionalAmount`
- Reset `betThisRound` to previous value

**Bet/Raise:**
- Calculate `previousBetThisRound` from prior actions
- Calculate `additionalAmount = amount - previousBetThisRound`
- Restore stack: `+= additionalAmount`
- Restore pot: `-= additionalAmount`
- Reset `betThisRound` to previous value
- Recalculate `currentBet` from remaining bets/raises
- Recalculate `hasBetThisRound` flag
- Recalculate all players' `hasCalledCurrentBet` status

### 4. Helper Methods (poker_hand_screen.dart:3600-3685)

**`_getPreviousBetThisRound(playerId, beforeIndex)`**
- Looks at all prior actions by same player in same street
- Returns the amount they had already bet before the undone action
- Critical for calculating additional amount correctly

**`_recalculateCurrentBet(upToIndex)`**
- Finds highest bet/raise amount in remaining actions
- Updates `gameState.currentBet` accordingly

**`_recalculateHasBetThisRound(upToIndex)`**
- Checks if any bet/raise exists in remaining actions
- Updates `gameState.hasBetThisRound` flag

**`_recalculateAllPlayersCallStatus(upToIndex)`**
- Resets all players' `hasCalledCurrentBet` status
- Marks players who acted after last bet/raise as having called

### 5. Critical Bug Fixes

#### Bug #1: CALL Amount Not Recorded (poker_hand_screen.dart:2504-2510)

**Problem:**
- CALL actions triggered by gestures went through `_performPokerAction()`
- No amount was being recorded for calls
- Undo couldn't restore pot because amount was 0

**Fix:**
```dart
// For call actions, calculate the amount being called
double? actionAmount;
if (action == PlayerAction.call) {
  final player = gameState.players[gameState.currentPlayer - 1];
  final callAmount = gameState.getCurrentBet() - player.betThisRound;
  actionAmount = callAmount.clamp(0.0, player.currentStack);
}
```

#### Bug #2: Incorrect Pot Restoration

**Problem:**
- Was restoring full bet amount instead of additional amount
- Example: SB posts $5, then calls $30 raise
  - SB's total bet = $30, but only added $25 MORE to pot
  - Undo was adding back $30 to stack and removing $30 from pot
  - This was wrong! Should only restore the $25 additional amount

**Fix:**
```dart
// Calculate what the player had bet BEFORE this action
double previousBetThisRound = _getPreviousBetThisRound(playerId, lastActionIndex);

// Calculate the additional amount that was added to pot
double additionalAmount = amount - previousBetThisRound;

// Restore stack (add back only the additional amount)
player.currentStack += additionalAmount;

// Restore pot (subtract only the additional amount)
gameState.currentPot -= additionalAmount;

// Restore bet tracking to previous value
player.betThisRound = previousBetThisRound;
```

#### Bug #3: Actions Saved to Firebase Immediately (hand_state_machine.dart:572-588)

**Problem:**
- Actions were being saved to Firebase in real-time
- Undo only removed from memory, not from database
- Created data inconsistency

**Fix:**
- Disabled `FirebaseService.saveAction()` in `recordAction()`
- Actions now stored only in memory during hand
- All actions saved to Firebase only when hand completes via `saveHand()` (line 759)

## Testing Verification

**Test Scenario:**
1. Pot = $5, UTG calls $2 → Pot = $7 ✅
2. UTG+1 raises to $6 → Pot = $13 ✅
3. Undo UTG+1's raise: Pot = $13 - $6 = $7 ✅
4. Undo UTG's call: Pot = $7 - $2 = $5 ✅

**State Restoration Verified:**
- ✅ Player stacks restored correctly
- ✅ Pot amounts roll back accurately
- ✅ BetThisRound values restored
- ✅ Current player set back to undone player
- ✅ Betting round reopened
- ✅ No duplicate actions in database

## Example Usage

**User Mistake:**
1. User logs Player 5 as fold (misclick)
2. Realizes mistake immediately
3. Clicks "Undo Last Action" button
4. Player 5's fold is undone
5. Player 5 is back to act
6. User logs correct action (check)

**Multiple Undos:**
1. User logs 5 actions
2. Realizes mistake on action #3
3. Clicks undo 3 times to roll back to that point
4. All pot/stack amounts restored correctly
5. Re-logs correct actions from that point

## Files Modified

- `lib/screens/poker_hand_screen.dart`
  - Added undo button UI (lines 1179-1195)
  - Added `_canUndoLastAction()` validation (lines 3375-3404)
  - Added `_undoLastAction()` core logic (lines 3406-3598)
  - Added helper methods (lines 3600-3685)
  - Fixed CALL amount recording (lines 2504-2510)

- `lib/models/hand_state_machine.dart`
  - Disabled real-time Firebase action saves (lines 572-588)
  - Actions now saved only when hand completes

## Design Decisions

### Why Only Undo Non-Blind Actions?

Blind posts are automatic and structural to the game. Allowing undo of blinds could corrupt the game state and pot calculations. Users should never need to undo blind posts.

### Why Calculate Additional Amount?

In poker, players can act multiple times in the same street (e.g., SB posts, then calls a raise). The `amount` field stores the **total bet at that point**, not the additional chips added. For accurate pot restoration, we must calculate:

```
additionalAmount = currentBet - previousBet
```

This ensures pot and stack changes match exactly.

### Why Store Actions in Memory Until Hand Completes?

**Benefits:**
1. Undo operations don't require database modifications
2. No partial/corrupted hand data in Firebase
3. Simpler undo logic (just remove from array)
4. Better performance (one write vs many writes)
5. Clean separation: memory = working state, DB = final state

## Edge Cases Handled

1. **Player all-in then undo**: `isAllIn` flag reset correctly
2. **Multiple actions by same player**: Previous bet calculated from action history
3. **Undoing raises**: Other players' `hasCalledCurrentBet` recalculated
4. **Undoing last action before river**: Betting round reopened
5. **Undo when no actions exist**: Validation prevents error
6. **Blind posts**: Cannot be undone (validation check)

## Future Improvements

- Consider adding undo limit (e.g., max 10 undos per hand)
- Add visual confirmation dialog for undo
- Track undo count for analytics
- Consider redo functionality (undo the undo)

## Conclusion

The undo functionality is fully implemented and tested. It properly handles all poker action types with accurate state restoration, prevents database complications by storing actions in memory, and provides a clean user experience for correcting hand logging mistakes.

---

**Related Diary Entries:**
- `2025-11-02-position-bug-debug-analysis.md` (Debug Hand Viewer analysis)
