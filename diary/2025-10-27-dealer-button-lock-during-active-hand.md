# Dealer Button Lock During Active Hand

**Date:** October 27, 2025
**Status:** ✅ Resolved
**Severity:** Critical - Button movement mid-hand broke game logic

## Problem Statement

The dealer button could be moved at any time through the "Manage Players" screen, including during active hands. When the button was moved after players had already acted (e.g., after UTG folds), the action order would recalculate, causing severe issues:

**Example Scenario:**
1. Hand starts, blinds posted, UTG folds
2. User opens "Manage Players" and moves dealer button
3. Action order recalculates based on new button position
4. UTG (now in different position) is skipped because they already folded
5. Game logic completely broken - action order corrupted, folded players skipped

## Requirements (Clarified)

The button should be movable in specific situations:
- ✅ **Before hand starts**: No restrictions
- ✅ **After blinds posted, before first action**: Button can still be moved to restart hand with new positions
- ❌ **After any player acts** (fold/call/raise): Button is LOCKED until hand completes
- ✅ **After hand completes**: Button unlocked again for next hand

**Key Rule:** Once ANY player takes an action, the hand has truly started and button cannot be moved.

## Solution Implementation

### Simple Check: Has Any Player Acted?

**Added `_isButtonLocked()` method in seat_setup_screen.dart** (lines 72-86):
```dart
/// Check if button can be moved
/// Button is locked once any player has acted (folded/called/raised)
/// Button can be moved: before hand starts, or after blinds posted but before first action
bool _isButtonLocked() {
  if (widget.gameState == null) return false;

  // Check if any player has acted
  for (final player in widget.gameState!.players) {
    if (player.isActive && player.hasActed) {
      return true; // At least one player acted, button is locked
    }
  }

  return false; // No actions taken yet, button can be moved
}
```

**Conditional button rendering** (lines 964-1053):
```dart
child: _isButtonLocked()
  ? // Button is locked - show with lock icon
    Opacity(
      opacity: 0.6,
      child: Stack(
        children: [
          Image.asset('icons/button.png', width: 32, height: 32),
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
  : // Button is unlocked - can be dragged
    Draggable<int>(
      // ... existing drag logic
    ),
```

**Warning message in header** (lines 758-763):
```dart
Text(
  _isButtonLocked()
      ? 'Button locked - hand in progress'
      : 'Update player information',
  style: TextStyle(
    color: _isButtonLocked() ? Colors.red.withOpacity(0.8) : Color(0xFF9A9A9A),
  ),
),
```

### Backend Protection

**Modified poker_hand_screen.dart** (line 553):
```dart
// Only recalculate action order during active preflop betting
else if ((buttonChanged || activeCountChanged) &&
         !gameState.bettingRoundComplete &&
         gameState.currentRound == BettingRound.preflop)
```

This prevents action order recalculation in most cases when button changes.

## How It Works

### State Flow

1. **New hand starts, blinds posted**
   - All players: `hasActed = false`
   - Button: **UNLOCKED** ✅
   - User can move button and restart with new positions

2. **UTG takes action** (fold/call/raise)
   - UTG: `hasActed = true`
   - Button: **LOCKED** ❌
   - Button shows lock icon, cannot be dragged

3. **Hand progresses** (more actions, streets, etc.)
   - Multiple players: `hasActed = true`
   - Button: **LOCKED** ❌

4. **Hand completes, new hand starts**
   - All players reset: `hasActed = false`
   - Button: **UNLOCKED** ✅
   - Cycle repeats

### Visual Feedback

When button is locked:
- 60% opacity (dimmed)
- Red lock icon overlay
- Header message: "Button locked - hand in progress" (red text)
- Button cannot be dragged

## Files Modified

1. **lib/screens/seat_setup_screen.dart**
   - Added `_isButtonLocked()` method (lines 72-86)
   - Conditional button rendering with lock visual (lines 964-1053)
   - Warning message in header (lines 758-763)

2. **lib/screens/poker_hand_screen.dart** (line 553)
   - Restrict action order recalculation to active preflop only

## Testing Scenarios

**Scenario 1: Button unlocked before first action ✅**
1. Start hand, blinds posted
2. Open "Manage Players"
3. **Result**: Button is draggable, no lock icon
4. Move button, return to game
5. **Result**: Hand restarts with new button position

**Scenario 2: Button locks after first action ❌**
1. Start hand, UTG folds
2. Open "Manage Players"
3. **Result**: Button shows lock icon, dimmed, "Button locked" message
4. Try to drag button
5. **Result**: Cannot drag, button stays in place

**Scenario 3: Button unlocks after hand completes ✅**
1. Complete a hand (any way - showdown, folds, etc.)
2. Start new hand (blinds posted, before actions)
3. Open "Manage Players"
4. **Result**: Button is draggable again

## Key Takeaways

1. **Simple Check**: Using `player.hasActed` flag is the cleanest way to determine if hand has truly started
2. **Player State Flags**: The game state already tracks what we need - just use it correctly
3. **Visual Feedback**: Lock icon + opacity + warning text clearly communicate the restriction
4. **Restart Capability**: Allowing button movement before first action gives flexibility to correct mistakes
5. **Clean Logic**: No complex state checks needed - just "has anyone acted?"

## Impact

- ✅ **CRITICAL FIX**: Button cannot be moved once hand starts (after first action)
- ✅ Players who acted are never skipped or affected by button changes
- ✅ Action order remains consistent throughout each hand
- ✅ Button can still be moved before first action (useful for corrections)
- ✅ Clear visual feedback when button is locked
- ✅ Game logic integrity fully preserved
- ✅ No more game-breaking bugs from mid-hand button movement
