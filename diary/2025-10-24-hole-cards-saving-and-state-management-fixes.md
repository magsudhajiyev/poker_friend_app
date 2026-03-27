# 2025-10-24: Hole Cards Saving and State Management Fixes

## Overview
Fixed critical issues with hole cards not being saved to database, BB Ante synchronization between dialogs, seat state management, and persistent hole card data across hands.

## Issues Fixed

### 1. Hole Cards Not Saving to Database
**Problem:** Hole cards were not being saved when everyone folded. User would select cards (e.g., pocket 7s, AK) but they wouldn't appear in hand history.

**Root Cause:** When everyone folds and hand completes automatically, `completeCurrentHand()` was called BEFORE showing the hole cards dialog. The hand was saved to Firebase with `ourHoleCards: null, null`.

**Debug Evidence:**
```
flutter: 💾 DEBUG: Saving hand #1 - ourHoleCards: null, null
flutter: 🃏 DEBUG: Hole cards dialog returned - card1: 7♦, card2: 2♦, isComplete: true
flutter: 🃏 DEBUG: Saved to completedHands.last (hand #1)
```

**Fix:** Modified `_completeHandAutomatically()` in `poker_hand_screen.dart` (line 3354-3400):
- Show hole cards dialog FIRST
- Save to `currentHand.ourHoleCards`
- THEN call `completeCurrentHand()` which moves `currentHand` (with hole cards) to `completedHands` and saves to Firebase

**Files Changed:**
- `lib/screens/poker_hand_screen.dart`: Reordered dialog and completion calls

### 2. Hole Cards Persisting Between Hands
**Problem:** When moving from Hand #1 to Hand #2, the hole cards dialog would open with Hand #1's cards already selected instead of starting fresh.

**Root Cause:** The `_showHoleCardsDialog()` method was loading `existingHoleCards` from `completedHands.last` instead of `currentHand`. When the dialog was shown for a new hand (before completion), it would show the previous hand's cards.

**Fix:** Modified `_showHoleCardsDialog()` logic (line 3786-3839):
```dart
// BEFORE (wrong):
if (isForCompletedHand && sessionManager.completedHands.isNotEmpty) {
  existingHoleCards = sessionManager.completedHands.last.ourHoleCards;
}

// AFTER (correct):
if (sessionManager.currentHand != null) {
  // Use the current hand being played/completed
  existingHoleCards = sessionManager.currentHand?.ourHoleCards;
} else if (sessionManager.completedHands.isNotEmpty) {
  // Fallback to last completed hand (for editing after hand is fully complete)
  existingHoleCards = sessionManager.completedHands.last.ourHoleCards;
}
```

**Rationale:** Always prioritize `currentHand` which is the hand being completed, ensuring fresh state for each new hand.

### 3. BB Ante Not Syncing Between Game Settings and Session Details
**Problem:** User enables BB Ante in Game Settings dialog (three-dot menu), but when opening Session Details screen to update blinds, BB Ante switch was off.

**Root Cause:** Two separate blind update locations weren't synchronized:
1. Game Settings dialog (from three-dot menu)
2. Session Details screen

**Fix Applied:**
- `poker_hand_screen.dart` (line 2945): Changed from `hasBBante: widget.hasBBante` to `hasBBante: gameState.hasBBante` to pass current state instead of initial widget value
- Updated `_SettingsDialog` class (line 4246-4268): Added `currentHasBBante` and `gameType` parameters
- Updated `onBlindsChanged` callback signature (line 4253): From `(smallBlind, bigBlind)` to `(smallBlind, bigBlind, hasBBante)`
- Added BB Ante switch to Game Settings dialog (line 4606-4635)
- Updated callback implementation (line 612-638): Now updates `gameState.hasBBante` and syncs to Firebase

**Files Changed:**
- `lib/screens/poker_hand_screen.dart`: Dialog parameters, callback signatures, Firebase sync
- `lib/models/poker_game_state.dart`: Removed debug logs

### 4. Seat Not Resetting When Player Leaves
**Problem:** When a player left (seat deactivated), then the seat was reactivated later, it showed the previous player's name and stack instead of "Player #" with default stack.

**Fix Applied:**
- `hand_state_machine.dart` (line 1160-1165): Modified `removePlayer()` to reset player name to "Player #" and remove stack from `playerStacks` map
- `seat_management_dialog.dart` (line 60-82): Initialize stack controllers from `sessionManager` if available
- `seat_management_dialog.dart` (line 661-685): When toggling seat to active, check if player name is "Player #" (indicating reset) and use default stack values

**Files Changed:**
- `lib/models/hand_state_machine.dart`: Reset seat state on player removal
- `lib/widgets/seat_management_dialog.dart`: Proper stack initialization and toggle handling

## Code Changes Summary

### hand_state_machine.dart
```dart
void removePlayer(int seatNumber) {
  activeSeats.remove(seatNumber);
  // Reset to initial state when seat is deactivated
  playerNames[seatNumber] = 'Player $seatNumber';
  playerStacks.remove(seatNumber);
}
```

### poker_hand_screen.dart
Key changes:
1. Reordered automatic hand completion to show dialog first
2. Fixed hole cards dialog to prioritize `currentHand` over `completedHands.last`
3. Added BB Ante parameter passing and synchronization
4. Added debug logging for troubleshooting (to be removed before final commit)

### seat_management_dialog.dart
- Proper stack controller initialization from sessionManager
- Smart toggle handling that detects reset seats

## Verified All Hand Completion Paths

1. ✅ **Everyone folds** (line 3356) - Shows dialog first, then completes
2. ✅ **All-in completion** (line 2774) - Shows dialog first, then completes
3. ✅ **Normal winner selection** (line 3527) - Shows dialog first, then completes

## Testing Results

**Before Fix:**
```
💾 DEBUG: Saving hand #1 - ourHoleCards: null, null
🃏 DEBUG: Hole cards dialog returned - card1: 7♦, card2: 2♦
🃏 DEBUG: Saved to completedHands.last (hand #1)
```

**After Fix:**
```
🃏 DEBUG: Hole cards dialog returned - card1: 7♦, card2: 2♦
🃏 DEBUG: Saved to currentHand (hand #1)
💾 DEBUG: Saving hand #1 - ourHoleCards: 7♦, 2♦
```

## Files Modified
- `lib/screens/poker_hand_screen.dart`
- `lib/models/hand_state_machine.dart`
- `lib/widgets/seat_management_dialog.dart`
- `lib/models/poker_game_state.dart`
- `lib/screens/individual_session_tracking_screen.dart`

## Next Steps
- Remove debug logging before production
- Test all scenarios: everyone folds, normal completion, all-in, chopped pots
- Verify hole cards save correctly in Firebase and display in hand history
