# Fix: Undo After Cancelling Board Card Dialog

**Date**: 2026-04-24
**Status**: Complete

## Problem

Two bugs when cancelling the board cards dialog and trying to undo actions:

### Bug 1: Street advance not fully rolled back
When a betting round completes, `startNewStreet()` runs **before** the card dialog appears. It clears all players' `betThisRound`, resets `currentBet`/`_lastRaiseSize`, finalizes pot into `streetPots`, and recalculates action order. The old `_rollbackStreetAdvance()` only restored `currentRound` and `bettingRoundComplete` — pot, bets, and player state remained corrupted.

### Bug 2: Call undo math wrong
`_undoLastAction()` treated all action amounts as "total bet at that point" and computed `additionalAmount = amount - previousBetThisRound`. But **call amounts are recorded as additional** (`getCurrentBet() - player.betThisRound`), not total. This caused under-subtraction from the pot, leaving extra money.

### Bug 3: Undo button not appearing
After rollback, `bettingRoundComplete` was restored to `true` (its value when the snapshot was taken), which prevented `_canUndoLastAction()` from returning true.

### Bug 4: Blind posts invisible to undo
`_getPreviousBetThisRound()` only scanned the action list for voluntary bet/raise/call actions. Blind posts (SB/BB) are applied directly in `initializePot()` and never recorded as actions, so the function returned 0 for players whose only prior contribution was a blind.

## Solution

### Snapshot/Restore for street advance (`poker_game_state.dart`)
- Added `_StreetSnapshot` and `_PlayerSnapshot` classes that capture all state modified by `startNewStreet()`
- Added `snapshotBeforeStreetAdvance()` — called before `startNewStreet()`
- Added `restoreFromStreetSnapshot()` — called on dialog cancel, restores everything
- Added `clearStreetSnapshot()` — called on successful card entry

### Call undo fix (`poker_hand_screen.dart`)
- Call amounts are additional, so undo now uses the recorded amount directly:
  ```dart
  player.currentStack += amount;
  player.betThisRound -= amount;
  gameState.currentPot -= amount;
  ```
- Bet/raise amounts are total, so undo still computes `amount - previousBetThisRound`

### Blind awareness in undo
- `_getPreviousBetThisRound()` now checks if the player is SB or BB when no prior voluntary action exists on preflop

### Undo button visibility
- `_rollbackStreetAdvance()` always sets `bettingRoundComplete = false` after restore

## Key Technical Details

### How amounts are recorded
| Action | Recorded Amount | Meaning |
|--------|----------------|---------|
| Call | `getCurrentBet() - player.betThisRound` | Additional amount put in |
| Bet/Raise | Total target amount | e.g., "raise to 18" |
| Fold/Check | 0 or null | No monetary value |

### State captured in snapshot
- `currentRound`, `currentBet`, `_lastRaiseSize`, `hasBetThisRound`, `bettingRoundComplete`
- `currentPot`, `currentPlayer`, `streetPots` (deep copy)
- Per-player: `hasActed`, `hasCalledCurrentBet`, `isAllIn`, `lastAction`, `betThisRound`, `totalContribution`, `currentStack`

## Files Changed

### Modified
- `lib/models/poker_game_state.dart` — `_StreetSnapshot`, `_PlayerSnapshot`, snapshot/restore/clear methods
- `lib/screens/poker_hand_screen.dart` — Snapshot call in `_proceedToNextStreet()`, full restore in `_rollbackStreetAdvance()`, fixed call undo math, blind-aware `_getPreviousBetThisRound()`

## Testing

1. 1/2 cash game, 5 players — cancel card dialog, undo all → pot returns to $3 (SB+BB) ✓
2. Undo button appears after cancelling dialog ✓
3. Player stacks correctly restored on undo ✓
4. Normal undo (without cancel) still works ✓
