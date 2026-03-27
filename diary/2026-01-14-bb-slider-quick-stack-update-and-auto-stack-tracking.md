# BB-Based Slider Quick Stack Update & Auto Stack Tracking

**Date:** January 14, 2026
**Branch:** `feature/bb-slider-stack-update`
**Status:** ✅ Completed and Merged

## Overview

Implemented a comprehensive BB-based slider interface for quick stack updates in individual hand logging, replacing the slow table view with an intuitive slider-based UI. Additionally, implemented automatic stack tracking across hands to eliminate manual stack adjustments between hands.

## Problem Statement

### Original Issues:
1. **Slow Table View Interface**: The previous table-based stack update screen was cumbersome and slow to use
2. **Manual Stack Adjustments**: Users had to manually update their stack every hand after logging
3. **Player Name Sync Issues**: Player names weren't transferring between screens
4. **Player Duplication**: Users appeared in multiple seats when changing positions
5. **Incorrect Stack Calculations**: Win/loss calculations used wrong baseline stack values
6. **Button Position Handling**: No automatic button movement when button seat became open
7. **Stack Limit Issues**: Slider capped at 200 BB, causing errors with larger stacks

## Solution Implemented

### 1. Quick Stack Update Screen (NEW)
**File:** `lib/screens/quick_stack_update_screen.dart`

A brand new screen with the following features:
- **BB-Based Sliders**: Adjust stacks using BB multiples instead of raw chip amounts
- **Dynamic Slider Range**: Automatically adjusts maximum based on largest stack (rounded to nearest 100 BB)
- **Visual Button Indicator**: Tap the 🟡 icon to set button position
- **Seat Open/Closed Toggle**: Mark seats as open with visual checkbox
- **Player Name Management**: Click player names to assign opponents or yourself
- **Opponent Search**: Searchable dialog for selecting opponents from database
- **Manual Stack Edit**: Tap stack to manually enter precise BB values (up to 1000 BB)
- **Real-time Position Labels**: Positions (UTG, CO, BTN, SB, BB, etc.) update dynamically based on:
  - Current button position
  - Active (non-open) seats
  - Total number of players

#### Auto-Button Movement
When the button seat is marked as open:
- Automatically finds next available seat clockwise
- Moves button to that seat
- Recalculates all positions instantly

#### Dynamic Slider Implementation
```dart
double _getSliderMaxBB() {
  double maxStack = 200.0; // Default minimum
  for (var stack in playerStacksInBB.values) {
    if (stack > maxStack) {
      maxStack = stack;
    }
  }
  // Round up to nearest 100 BB for cleaner slider range
  return ((maxStack / 100).ceil() * 100).toDouble();
}
```

### 2. Automatic Stack Tracking
**Core Concept:** User's stack is a property of the USER, not the SEAT

#### Implementation:
1. **Pass User Context**: `QuickStackUpdateScreen` receives:
   - `userCurrentStack`: User's current chip stack
   - `userName`: User's display name for detection

2. **Auto-Apply on Selection**: When user selects themselves for a seat:
   ```dart
   if (widget.userName != null &&
       widget.userCurrentStack != null &&
       selected == widget.userName) {
     playerStacksInBB[playerId] = widget.userCurrentStack! / widget.bigBlind;
   }
   ```

3. **Auto-Apply on Return**: When screen opens with user already seated:
   ```dart
   // In initState()
   if (widget.userName != null && widget.userCurrentStack != null) {
     int? userSeat;
     for (var entry in customPlayerNames.entries) {
       if (entry.value == widget.userName) {
         userSeat = entry.key;
         break;
       }
     }
     if (userSeat != null) {
       playerStacksInBB[userSeat] = widget.userCurrentStack! / widget.bigBlind;
     }
   }
   ```

4. **Track Across Hands**: Stack persists in `IndividualSessionTrackingScreen`:
   ```dart
   // After hand completes
   if (userSeat != null && playerStacks.containsKey(userSeat)) {
     _currentStack = playerStacks[userSeat]!;
   }
   ```

### 3. Player Name Synchronization
**Files Modified:**
- `lib/screens/poker_hand_screen.dart`
- `lib/screens/individual_session_tracking_screen.dart`

#### Changes:
1. Added `preConfiguredPlayerNames` parameter to `PokerHandScreen`
2. Modified `_initializeWithPreConfiguredData()` to accept and apply player names
3. Implemented explicit clearing pattern using empty string `''` to mark seats as cleared
4. Filter empty strings before returning to prevent propagation

### 4. Correct Stack Calculations
**File:** `lib/screens/poker_hand_screen.dart`

#### Implementation:
1. Store user's actual starting stack when initializing with pre-configured data:
   ```dart
   double? _userStartingStack;  // Track user's actual starting stack

   // Store in _initializeWithPreConfiguredData:
   _userStartingStack = initialStack;
   ```

2. Return starting stack with hand completion results:
   ```dart
   Navigator.pop(context, {
     'completed': true,
     'finalStack': finalStack,
     'startingStack': _userStartingStack ?? finalStack,  // ADDED
     'potSize': potSize,
   });
   ```

3. Calculate stack change using actual starting stack:
   ```dart
   final startingStack = result['startingStack'] as double?;
   final actualStartingStack = startingStack ?? _currentStack;
   final stackChange = newStack - actualStartingStack;
   ```

### 5. User Seat Detection
**File:** `lib/screens/poker_hand_screen.dart`

Fixed hardcoded user seat by finding which seat user selected for themselves:
```dart
int? ourSeatFromNames;
if (playerNames != null) {
  for (var entry in playerNames.entries) {
    if (entry.value == ourName) {
      ourSeatFromNames = entry.key;
      break;
    }
  }
}

if (ourSeatFromNames != null) {
  sessionManager.ourSeatNumber = ourSeatFromNames;
} else {
  // Default to first active seat
  int? firstActiveSeat;
  for (var entry in playerStacks.entries) {
    if (entry.value > 0) {
      firstActiveSeat = entry.key;
      break;
    }
  }
  sessionManager.ourSeatNumber = firstActiveSeat ?? 1;
}
```

## Technical Details

### Data Flow
```
IndividualHandSetupScreen
    ↓ (smallBlind, bigBlind, numberOfPlayers, gameType)
IndividualSessionTrackingScreen
    ↓ (+ currentStack, userName)
QuickStackUpdateScreen
    ↓ (playerStacks, buttonPosition, playerNames)
IndividualSessionTrackingScreen
    ↓ (merge with preConfiguredPlayerNames)
PokerHandScreen
    ↓ (hand completion with startingStack)
IndividualSessionTrackingScreen
    (update currentStack from result)
```

### Key State Variables
- `_currentStack` (IndividualSessionTrackingScreen): User's current chip stack
- `_lastPlayerStacks` (IndividualSessionTrackingScreen): Stack snapshot from previous hand
- `_lastPlayerNames` (IndividualSessionTrackingScreen): Name assignments from previous hand
- `_lastButtonPosition` (IndividualSessionTrackingScreen): Button position from previous hand
- `playerStacksInBB` (QuickStackUpdateScreen): Stack values in BB multiples
- `customPlayerNames` (QuickStackUpdateScreen): User-assigned player names
- `seatIsOpen` (QuickStackUpdateScreen): Seat availability status

## Files Changed

### New Files:
- `lib/screens/quick_stack_update_screen.dart` (new, 905 lines)

### Modified Files:
- `lib/screens/individual_session_tracking_screen.dart`
  - Added stack tracking logic
  - Integrated QuickStackUpdateScreen
  - Added player name merging
  - Fixed stack calculation with actual starting stack

- `lib/screens/poker_hand_screen.dart`
  - Added `preConfiguredPlayerNames` parameter
  - Store user's actual starting stack
  - Return starting stack in completion results
  - Fixed user seat detection
  - Removed debug logging

## Testing Scenarios Verified

1. ✅ First hand: Select yourself → Stack auto-applied
2. ✅ Second hand: Name already there → Stack auto-updated
3. ✅ Change positions: Move to different seat → Stack follows
4. ✅ Manual adjustment: Edit stack → Persists to next hand
5. ✅ Win/lose hand: Correct stack change calculation
6. ✅ Large stacks: Slider adjusts for stacks > 200 BB
7. ✅ Button on open seat: Button moves to next available seat
8. ✅ Player duplication: User appears in only one seat
9. ✅ Multiple hands: Stack persists across entire session

## Benefits

### User Experience:
- ⚡ **Faster Setup**: BB-based sliders are much faster than table input
- 🎯 **Automatic Stack Tracking**: No manual adjustments needed between hands
- 🔄 **Position Flexibility**: Stack follows user when changing seats
- 📊 **Accurate Calculations**: Win/loss tracking uses correct baseline
- 🎲 **Smart Button Handling**: Automatic button position management
- 📈 **No Stack Limits**: Supports stacks of any size

### Code Quality:
- 🏗️ **Single Source of Truth**: User stack tracked at session level
- 🔧 **Modular Design**: Clean separation between screens
- 🎨 **Consistent UI**: Matches app's design system
- 📝 **Well-Documented**: Extensive comments explain complex logic
- 🐛 **Error Handling**: Graceful degradation if data missing

## Edge Cases Handled

1. **Empty Player Names**: Falls back to "Player #" labels
2. **Missing Stack Data**: Defaults to 100 BB
3. **All Seats Open**: Button stays on current seat
4. **Very Large Stacks**: Slider max rounds up dynamically
5. **Manual Edit Limits**: Allows up to 1000 BB entry
6. **Position Changes**: Stack transfers correctly between seats
7. **First vs Subsequent Hands**: Different initialization paths both work

## Lessons Learned

1. **State Management**: Passing state through multiple screens requires careful planning
2. **Dynamic UI**: Slider ranges need to adapt to data, not hardcoded limits
3. **User Context**: Tracking user-specific data separately from seat-specific data is crucial
4. **Explicit Clearing**: Using empty string `''` is better than `remove()` for optional overrides
5. **Debug Logging**: Remove before merging to keep production logs clean

## Future Enhancements

### Potential Improvements:
- [ ] Save stack history for undo functionality
- [ ] Visual indicators for stack changes (green/red arrows)
- [ ] Preset stack sizes (50BB, 100BB, 200BB buttons)
- [ ] Remember opponent stacks across sessions
- [ ] Auto-detect button movement based on dealer rotation
- [ ] Stack size warnings (short stack alerts)

## Conclusion

This feature significantly improves the individual hand logging workflow by eliminating manual stack tracking and providing an intuitive BB-based interface. The automatic stack tracking ensures users can focus on logging hands rather than managing chip counts, while the dynamic UI adapts to any game size or stack depth.

The implementation demonstrates proper state management, user-centric design, and handles numerous edge cases that could arise during real gameplay.

---

**Merged:** January 14, 2026
**Commit:** `feat: implement BB-based quick stack update with automatic stack tracking`
