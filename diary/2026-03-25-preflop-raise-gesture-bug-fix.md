# Preflop Raise Gesture Bug Fix

**Date:** 2026-03-25

## Problem

When in manual logging mode, after a player calls on preflop, the next player couldn't raise using the L-shape gesture. The phone would vibrate (indicating invalid action) and the raise dialog wouldn't appear.

**Example scenario:**
- Blinds: 100/200
- UTG calls (200)
- UTG+1 draws L-shape to raise → Phone vibrates, can only call

## Root Cause

In `poker_hand_screen.dart`, the `recognizeShape()` function used `hasBetThisRound` to determine whether to trigger a BET or RAISE action:

```dart
// OLD CODE (BUGGY)
} else if (hasRightAngle()) {
  if (gameState.hasBetThisRound) {
    _enterDragBettingMode(PlayerAction.raise);
  } else {
    _enterDragBettingMode(PlayerAction.bet);
  }
}
```

**The issue:** On preflop, `hasBetThisRound` is `false` because the big blind is a forced bet, not tracked as a voluntary bet. So the code tried to do a BET action, but BET is invalid on preflop (must RAISE since BB counts as the opening bet). This triggered the invalid action vibration.

Meanwhile, the single-tap gesture correctly used `isValidAction()` to check validity:
```dart
// CORRECT LOGIC (single tap)
if (gameState.isValidAction(PlayerAction.bet)) {
  _enterDragBettingMode(PlayerAction.bet);
} else if (gameState.isValidAction(PlayerAction.raise)) {
  _enterDragBettingMode(PlayerAction.raise);
}
```

## Solution

Updated `recognizeShape()` to use `isValidAction()` instead of `hasBetThisRound`:

```dart
// NEW CODE (FIXED)
} else if (hasRightAngle()) {
  // Use isValidAction to determine correct action (handles preflop where bet is invalid)
  if (gameState.isValidAction(PlayerAction.bet)) {
    _enterDragBettingMode(PlayerAction.bet);
  } else if (gameState.isValidAction(PlayerAction.raise)) {
    _enterDragBettingMode(PlayerAction.raise);
  }
}
```

## Files Modified

- `lib/screens/poker_hand_screen.dart` - Line ~2063-2070 in `recognizeShape()` function

## Key Lesson

**Always use `isValidAction()` to determine valid poker actions** rather than relying on flags like `hasBetThisRound`. The `isValidAction()` method in `poker_game_state.dart` already handles all the edge cases:

- Preflop: BET is always invalid (returns `false`), RAISE is always valid
- Post-flop: BET is valid if no one has bet, RAISE is valid if someone has bet

## Related Code Reference

`poker_game_state.dart` - `isValidAction()` method:
```dart
case PlayerAction.bet:
  // Cannot bet preflop - must raise instead since BB is already a "bet"
  if (currentRound == BettingRound.preflop) {
    return false;
  }
  return !hasBetThisRound;

case PlayerAction.raise:
  // Preflop: can always raise (since BB is always a "bet")
  if (currentRound == BettingRound.preflop) {
    return true;
  }
  return hasBetThisRound;
```

## Testing

1. Start a cash game session
2. On preflop, have UTG call
3. As UTG+1, draw an L-shape gesture
4. Verify: Raise amount dialog should appear (not vibrate)
