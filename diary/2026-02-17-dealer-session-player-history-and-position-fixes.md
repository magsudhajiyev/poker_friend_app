# Dealer Session: Player History, Stack Tracking, and Position Fixes

**Date:** 2026-02-17
**Branch:** feature/dealer-assisted-logging
**Status:** Resolved

---

## Overview

This session addressed multiple interconnected issues with the dealer-assisted logging feature, specifically around:
1. Player stacks not being captured in hand details
2. Dealer sessions not appearing in player's Session History
3. Position names showing incorrectly (multiple BTN/SB and BB)
4. Hands not displaying when viewing logged hands from Session History

---

## Issue 1: Player Stacks Not Captured

### Symptom
Player stacks showed as "-" in hand details after completing a hand via dealer mode.

### Root Cause
The `_getPlayer()` lookup in `PokerGameState` could fail and return a default `PlayerState` with stack 0. The `getPlayerStack()` method relied on this lookup.

### Fix
Changed `_performAction()` in `dealer_table_screen.dart` to use direct array access instead of method-based lookup:

```dart
// Before (unreliable)
final playerStack = _gameState!.getPlayerStack(currentSeat);

// After (reliable)
var playerStack = _gameState!.players[currentSeat - 1].currentStack;

// With fallback for safety
if (playerStack <= 0) {
  playerStack = _sessionManager!.getPlayerStack(currentSeat) ??
                (_dealerSession.bigBlind * 100.0);
}
```

Also updated `_syncPlayersFromSeats()` to use BOTH direct array access AND method-based updates:
```dart
_gameState!.players[i - 1].setStack(stack);
_gameState!.players[i - 1].isActive = true;
_gameState!.setPlayerStack(i, stack);
_gameState!.setPlayerActive(i, true);
```

### Files Modified
- `lib/screens/dealer/dealer_table_screen.dart`

---

## Issue 2: Dealer Sessions Not in Player's Session History

### Symptom
After a dealer session ended, players who participated could not see the session in their Session History.

### Root Cause
Two separate data systems with no link:
- **Dealer sessions** stored in `dealer_sessions` collection
- **Player sessions** stored in `poker_sessions` collection

When dealer session ended, no records were created in `poker_sessions` for participating players.

### Fix
1. Created `_createPlayerSessionRecord()` in `DealerService` to create `poker_sessions` records for each player when dealer session ends.

2. Updated `DealerService.endSession()` to iterate through all players and create session records:
```dart
for (final entry in session.players.entries) {
  final player = entry.value;
  if (player.playerId.isNotEmpty && !player.playerId.startsWith('manual_')) {
    await _createPlayerSessionRecord(
      dealerSession: session,
      sessionId: sessionId,
      playerId: player.playerId,
      playerName: player.displayName,
      seatNumber: entry.key,
      endTime: endTime,
    );
  }
}
```

3. The session record includes `isDealerSession: true` and `dealerSessionId` to link back to the original dealer session for fetching hands.

### Additional Fix: Players Added After Session Start
Discovered that players who joined AFTER the session started were not being added to the dealer session's `players` map. Fixed by calling `DealerService.addPlayer()` after:
- `SeatService.approveJoin()` - approving pending players
- `SeatService.seatUserDirectly()` - adding registered users
- `SeatService.addManualPlayer()` - adding walk-up players

### Files Modified
- `lib/services/dealer_service.dart`
- `lib/screens/dealer/dealer_table_screen.dart`
- `lib/screens/session_history_screen.dart` (added "Live" badge for dealer sessions)

---

## Issue 3: Position Names Showing Incorrectly

### Symptom
Multiple players showed "BTN/SB" and "BB" positions in hand details. Positions alternated in a repeating pattern instead of being unique.

### Root Cause
`playerCount` was saved as 9 (max table size) instead of actual active player count. When displaying hand details, positions were recalculated using this incorrect count, causing the modulo operation to cycle through positions incorrectly.

### Fix
Save `playerPosition` directly in each action record during hand logging, calculated using actual active seats:

```dart
// Get list of active seat numbers
final activeSeats = <int>[];
for (int i = 1; i <= 9; i++) {
  if (_gameState!.players[i - 1].isActive) {
    activeSeats.add(i);
  }
}

// Calculate position using active seats
final playerPosition = PokerPositions.getPositionNameForActivePlayers(
  currentSeat,
  _gameState!.buttonPosition,
  activeSeats,
);
```

This ensures positions are calculated ONCE at action time using the correct player count, then stored for display.

### Files Modified
- `lib/services/dealer_service.dart` (added `playerPosition` parameter to `logAction()`)
- `lib/screens/dealer/dealer_table_screen.dart` (calculate and pass position)

---

## Issue 4: Hands Not Displaying in Session History View

### Symptom
When tapping "View Logged Hands" from a dealer session in Session History, the screen showed "No Hands Logged" even though hands were logged.

### Root Cause
Two separate issues:

1. **SessionHandsScreen** always used `FirebaseService.getSessionHands()` with the `poker_sessions` document ID, but dealer session hands are stored in `dealer_sessions/{dealerSessionId}/hands`.

2. **Timestamp type mismatch**: `DealerService.getSessionHands()` returned raw Firestore Timestamps, but the UI expected ISO string format (like `FirebaseService.getSessionHands()` returns).

### Fix

1. Updated `SessionHandsScreen._loadHands()` to check for dealer sessions:
```dart
final isDealerSession = widget.session['isDealerSession'] == true;
final dealerSessionId = widget.session['dealerSessionId'] as String?;

if (isDealerSession && dealerSessionId != null) {
  loadedHands = await DealerService.getSessionHands(dealerSessionId);
} else {
  loadedHands = await FirebaseService.getSessionHands(widget.session['id']);
}
```

2. Updated `DealerService.getSessionHands()` to convert Timestamps to ISO strings:
```dart
return {
  'id': doc.id,
  'sessionId': sessionId,
  ...data,
  'startTime': (data['startTime'] as Timestamp?)?.toDate().toIso8601String() ?? DateTime.now().toIso8601String(),
  'endTime': (data['endTime'] as Timestamp?)?.toDate().toIso8601String(),
};
```

3. Also updated `SessionAnalyticsScreen` to use the same dealer session logic.

### Files Modified
- `lib/screens/session_hands_screen.dart`
- `lib/screens/session_analytics_screen.dart`
- `lib/services/dealer_service.dart`

---

## Summary of All Files Modified

| File | Changes |
|------|---------|
| `lib/services/dealer_service.dart` | Added `playerPosition` to `logAction()`, `addPlayer()` calls, `_createPlayerSessionRecord()`, Timestamp conversion in `getSessionHands()` |
| `lib/screens/dealer/dealer_table_screen.dart` | Fixed stack retrieval (direct array access), added position calculation, added `DealerService.addPlayer()` calls after seating players |
| `lib/screens/session_analytics_screen.dart` | Added dealer session check for fetching hands |
| `lib/screens/session_hands_screen.dart` | Added dealer session check for fetching hands, import for DealerService |
| `lib/screens/session_history_screen.dart` | Added "Live" badge for dealer sessions |

---

## Key Learnings

1. **Two-system architecture**: Dealer sessions and player sessions are stored separately. When features span both, explicit linking is required.

2. **Direct array access vs method lookup**: In Flutter/Dart state management, direct array access (`players[i-1]`) can be more reliable than method-based lookups that may return default values on failure.

3. **Timestamp handling**: Firestore returns `Timestamp` objects. Different parts of the app may expect ISO strings. Always normalize data format at the service layer.

4. **Position calculation**: Should be done ONCE at action time with correct context, not recalculated at display time with potentially stale data.

5. **Late joiners**: Players who join after a session starts need special handling - they must be added to session state, not just seat state.

---

## Testing Checklist

- [x] Start dealer session
- [x] Add players (via QR, direct add, test players)
- [x] Start and complete hands
- [x] Verify stacks show correctly in hand details
- [x] Verify positions are unique (one BTN, one SB, one BB)
- [x] End session
- [x] Verify session appears in player's Session History with "Live" badge
- [x] Verify "View Logged Hands" shows all logged hands
- [x] Verify hand details display correctly
