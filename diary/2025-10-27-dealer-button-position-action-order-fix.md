# Dealer Button Mid-Hand Movement Prevention Fix

**Date:** October 27, 2025
**Status:** ✅ Resolved
**Severity:** Critical - Button movement during active hand completely broke game logic

## Problem Statement

The dealer button could be moved **during an active hand** through the "Manage Players" screen. This caused severe game-breaking issues:

**Example Scenario:**
1. Hand starts, UTG folds
2. User opens "Manage Players" and moves the dealer button
3. Action order recalculates based on new button position
4. When action reaches UTG (now in a different position), they are skipped because they already folded
5. Game logic breaks completely - folded players skipped, action order corrupted

**Root Issue**: There was no prevention mechanism to stop users from moving the button during active play. The button should ONLY be movable when:
- ✅ A hand has finished (betting complete)
- ✅ Next hand hasn't started yet

## Root Cause Analysis

The dealer button was fully functional and draggable in `seat_setup_screen.dart` at all times, with no checks to prevent movement during active hands.

**In seat_setup_screen.dart** (lines 992-1059):
```dart
// Button was ALWAYS draggable
Draggable<int>(
  data: seatNumber,
  onDragEnd: (details) {
    // Find closest seat and move button
    setState(() {
      selectedButtonPosition = closestSeat;
    });
  },
  child: Image.asset('icons/button.png'),
)
```

**The Problem Chain:**
1. **No prevention**: Button could be dragged at any time during the session
2. **Mid-hand movement**: If moved during active hand, action order would recalculate
3. **Player state corruption**: Players who already acted (folded, raised, etc.) maintained their state
4. **Action order mismatch**: New action order didn't account for previous actions in the same hand
5. **Result**: Folded players could be skipped when action reached them in new positions, or action could skip active players entirely

**Additional Issue in poker_hand_screen.dart** (lines 553-591):
When button changed mid-hand, the code tried to recalculate action order immediately, which caused even more problems during active betting.

## Solution Implementation

### Fix 1: Prevent Button Movement During Active Hand (seat_setup_screen.dart)

**Added helper method to detect active hands** (lines 72-91):
```dart
/// Check if a hand is currently active (button cannot be moved during active hand)
bool _isHandActive() {
  if (widget.gameState == null) return false;

  final activePlayers = widget.gameState!.getActivePlayers();
  if (activePlayers.length < 2) return false; // No active hand with less than 2 players

  // If betting round is not complete, hand is definitely active
  if (!widget.gameState!.bettingRoundComplete) return true;

  // If we're not at river or hand hasn't completed all streets, hand is active
  if (widget.gameState!.currentRound != BettingRound.river) return true;

  return false; // Hand is complete, button can be moved
}
```

**Replaced always-draggable button with conditional rendering** (lines 969-1059):
```dart
child: _isHandActive()
  ? // Hand is active - show locked button with visual indicator
    Opacity(
      opacity: 0.5,
      child: Stack(
        children: [
          Image.asset('icons/button.png', width: 32, height: 32),
          // Lock icon overlay
          Positioned.fill(
            child: Icon(
              Icons.lock,
              color: Colors.red.withOpacity(0.8),
              size: 16,
            ),
          ),
        ],
      ),
    )
  : // Hand not active - button is draggable
    Draggable<int>(
      // ... existing drag logic
    ),
```

**Added warning message in header** (lines 763-768):
```dart
Text(
  _isHandActive()
      ? 'Update player information. Button locked during hand.'
      : 'Update player information',
  style: TextStyle(
    color: _isHandActive() ? Colors.red.withOpacity(0.8) : Color(0xFF9A9A9A),
  ),
),
```

### Fix 2: Prevent Mid-Hand Action Order Recalculation (poker_hand_screen.dart)

**Modified condition to only recalculate during active preflop** (line 553):
```dart
// Before:
else if ((buttonChanged || activeCountChanged) && !gameState.bettingRoundComplete)

// After:
else if ((buttonChanged || activeCountChanged) &&
         !gameState.bettingRoundComplete &&
         gameState.currentRound == BettingRound.preflop)
```

This ensures action order is ONLY recalculated if we're actively in preflop betting, not during postflop or between hands.

### Fix 3: Button Position Setter Cleanup (poker_game_state.dart)

Simplified logic and removed debug logging (lines 117-130):
```dart
set buttonPosition(int value) {
  if (_buttonPosition != value) {
    _buttonPosition = value;
    if (!_isInitializing) {
      // Only recalculate immediately if we're in preflop with active betting
      if (currentRound == BettingRound.preflop && !bettingRoundComplete) {
        _setInitialActionOrder();
      }
      // Otherwise, action order will be recalculated when next hand/street starts
    }
  }
}
```

## Files Modified

1. **lib/screens/seat_setup_screen.dart**
   - Added `_isHandActive()` method to detect if hand is in progress (lines 72-91)
   - Made button conditionally draggable vs locked (lines 969-1059)
   - Added lock icon visual indicator when hand is active
   - Added warning message in header when button is locked (lines 763-768)

2. **lib/screens/poker_hand_screen.dart** (Line 553)
   - Added `&& gameState.currentRound == BettingRound.preflop` to condition
   - Prevents action order recalculation during postflop or between hands
   - Only recalculates if actively in preflop betting

3. **lib/models/poker_game_state.dart** (Lines 117-130)
   - Cleaned up `buttonPosition` setter
   - Removed debug logging
   - Added clarifying comments

## Testing Scenarios

**Scenario 1: Try to move button mid-hand (CRITICAL TEST)**
1. Start a session with 5+ players
2. Start a hand, have UTG fold
3. Open "Manage Players" during active betting
4. **Expected**: Button shows lock icon, cannot be dragged, header shows warning
5. **Before fix**: Button could be moved, causing folded players to be skipped

**Scenario 2: Move button between hands**
1. Complete a hand (any street)
2. Open "Manage Players" after hand finishes
3. **Expected**: Button is draggable, no lock icon
4. Move button to different seat
5. Start next hand
6. **Expected**: Action starts from UTG, game proceeds normally

**Scenario 3: Button lock at different game states**
1. Test button lock status at:
   - During preflop betting (locked)
   - During flop betting (locked)
   - During turn betting (locked)
   - During river betting (locked)
   - After river completes (unlocked)
   - Between hands (unlocked)
2. **Expected**: Locked during ALL active betting, unlocked only when hand complete

**Scenario 4: Visual feedback**
1. Open "Manage Players" during active hand
2. **Expected**:
   - Button has 50% opacity
   - Red lock icon overlay visible
   - Header message: "Button locked during hand" in red text
   - Button cannot be dragged

## Key Takeaways

1. **Prevention > Correction**: Better to prevent invalid actions than to handle consequences
2. **Player State Integrity**: Moving button mid-hand corrupts player states (folded, acted, etc.)
3. **Visual Feedback**: Clear visual indicators (lock icon, opacity, warning text) help users understand restrictions
4. **Game State Validation**: Always check if critical actions (like button movement) are valid in current game state
5. **Multi-Layer Protection**:
   - UI layer: Disable drag functionality
   - Visual layer: Show lock icon and warning
   - Backend layer: Don't recalculate action order mid-hand

## Impact

- ✅ **CRITICAL**: Button can no longer be moved during active hands
- ✅ Players who folded are never skipped when action reaches them
- ✅ Action order remains consistent throughout each hand
- ✅ Clear visual feedback when button is locked
- ✅ Game logic integrity preserved
- ✅ Button can still be moved between hands as intended
- ✅ No more game-breaking bugs from mid-hand button movement
