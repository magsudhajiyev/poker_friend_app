# River Completion Winner Dialog Fix

**Date:** 2026-03-25

## Problem

When a hand completed normally on the river (e.g., check-check), the winner selection dialog did not appear. The user could only proceed to the next hand without selecting a winner, causing incomplete hand data.

**Example scenario:**
- Hand reaches river with 2+ players
- Player 1 checks
- Player 2 checks
- Betting round complete, but no winner dialog appears
- User stuck without ability to record winner

## Root Cause

In `poker_hand_screen.dart`, both `_performPokerActionWithAmount()` and `_performPokerAction()` functions had logic to handle betting round completion, but only for non-river rounds:

```dart
// OLD CODE (BUGGY)
if (gameState.bettingRoundComplete && gameState.currentRound != BettingRound.river) {
  _schedulePostFrameAction(() {
    // ... advance to next street
    nextStreet();
  });
}
// No handling for river completion!
```

**The issue:** The code explicitly excluded the river round (`currentRound != BettingRound.river`) but never added a separate case to handle river completion. When betting completed on the river, nothing happened.

## Solution

Added a new condition to handle river betting completion in both functions:

```dart
// NEW CODE (FIXED)
if (gameState.bettingRoundComplete && gameState.currentRound != BettingRound.river) {
  _schedulePostFrameAction(() {
    // ... advance to next street
    nextStreet();
  });
} else if (gameState.bettingRoundComplete && gameState.currentRound == BettingRound.river) {
  // River betting complete - trigger showdown/winner selection
  _schedulePostFrameAction(() {
    // Save river pot before completing hand
    sessionManager.savePotForStreet(BettingRound.river, gameState.currentPot);
    _handleHandComplete();
  });
}
```

## Files Modified

- `lib/screens/poker_hand_screen.dart`
  - Line ~2694 in `_performPokerActionWithAmount()` function
  - Line ~2879 in `_performPokerAction()` function

## Key Lesson

**When handling betting round completion, remember all four rounds need consideration:**
- Preflop → advance to flop
- Flop → advance to turn
- Turn → advance to river
- River → trigger showdown/winner selection

The original code used `!= BettingRound.river` to advance streets (since river has no next street), but forgot to add the complementary `== BettingRound.river` case for hand completion.

## Testing

1. Start a cash game session
2. Play a hand through to the river
3. Have the action end with check-check (or any betting that completes the round)
4. Verify: Winner selection dialog should appear
5. Select winner and verify hand completes properly
