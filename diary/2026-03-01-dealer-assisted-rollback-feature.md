# Dealer-Assisted Mode: Rollback/Undo Action Feature

**Date**: 2026-03-01

## Summary
Added a rollback button to dealer-assisted logging mode that allows undoing the last action when voice recognition makes a mistake. The button properly restores chips, pot, and player state.

## Problem
In dealer-assisted voice logging mode, voice recognition can misinterpret commands, causing incorrect actions to be logged. There was no way to undo these mistakes without restarting the hand.

## Solution

### 1. Rollback Button UI
Added a semi-transparent circular button in the bottom-right corner of the table view:
- 85% opacity when active, 30% when disabled
- Orange border/icon when active, gray when disabled
- Fade effect animation

### 2. Undo Logic (`_undoLastAction()`)
Handles restoration for all action types:
- **Fold**: Restores `hasFolded = false`
- **Check**: Resets action state
- **Call/Bet/Raise**: Returns chips to player, reduces pot, restores `betThisRound`

### 3. Key Fixes During Implementation

**Issue 1: Action amount was null**
- Root cause: CALL actions weren't recording the amount
- Fix: Calculate call amount in `_performAction()` before recording:
  ```dart
  if (action == PlayerAction.call && recordAmount == null) {
    recordAmount = _gameState!.getCurrentBet() - player.betThisRound;
  }
  ```

**Issue 2: currentBet reset to 0 after undo**
- Root cause: `_recalculateCurrentBet()` only looked at bet/raise actions, not blinds
- Fix: Ensure minimum bet is BB on preflop:
  ```dart
  if (currentStreet == BettingRound.preflop && maxBet == 0) {
    maxBet = _dealerSession.bigBlind.toDouble();
  }
  ```

### 4. Supporting Methods
- `_canUndoLastAction()` - Validates if undo is possible
- `_getPreviousBetThisRound()` - Gets player's bet before undone action
- `_recalculateCurrentBet()` - Recalculates max bet after undo
- `_recalculateHasBetThisRound()` - Recalculates if bet occurred
- `_recalculateAllPlayersCallStatus()` - Rebuilds call status for all players
- `_showHandResetDialog()` - Shows dialog when all actions undone
- `_abortAndRestartHand()` - Resets hand and returns all bets

## Files Modified
- `/lib/screens/dealer/dealer_table_screen.dart`
  - Added rollback button UI in `_buildTableView()`
  - Added undo methods and helper functions
  - Fixed action amount recording in `_performAction()`

## Verification
1. Start dealer-assisted session
2. Execute actions (call, raise, fold)
3. Tap rollback button
4. Verify: chips restored, pot reduced, player state reset
5. Works for multiple consecutive undos
6. Shows reset dialog when all actions undone

## Related Features
- Manual logging undo in `poker_hand_screen.dart` (reference implementation)
- Voice command processing in dealer mode
