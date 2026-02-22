# TODO: Blinds Controlled by Event, Not Dealer

**Date:** 2026-02-21
**Branch:** feature/dealer-assisted-logging
**Status:** TODO (Critical Feature)
**Priority:** High

---

## Problem Statement

Currently, dealers can set blind levels when starting a session. This causes issues with:

1. **Rotating dealers**: Each dealer might set different blinds
2. **Inconsistency**: Blinds should be consistent across all tables in an event
3. **Tournament integrity**: Blind structure should be managed centrally by club admin

---

## Current Behavior

1. Dealer scans table QR and starts session
2. Dealer manually enters small blind and big blind
3. Each dealer can set different values
4. No connection between event blind structure and dealer session

---

## Expected Behavior

1. Club admin sets blind structure when creating event
2. Dealer scans table QR and starts session
3. **Blinds auto-populated from event settings** - dealer cannot change
4. Dealer only has "Blinds Up" button to advance to next level
5. If blinds change mid-hand, new blinds apply from NEXT hand
6. All tables in event stay synchronized

---

## Implementation Notes

### 1. Event Blind Structure (Club Admin)

**Add to ClubEvent model:**
```dart
class ClubEvent {
  // ... existing fields
  final List<BlindLevel> blindStructure;
  final int currentBlindLevelIndex;
}

class BlindLevel {
  final int smallBlind;
  final int bigBlind;
  final int ante;          // Optional ante
  final int? durationMinutes;  // For auto-advance (optional)

  BlindLevel({
    required this.smallBlind,
    required this.bigBlind,
    this.ante = 0,
    this.durationMinutes,
  });
}
```

**Default structures for quick setup:**
```dart
static final List<BlindLevel> defaultCashGameBlinds = [
  BlindLevel(smallBlind: 1, bigBlind: 2),
  BlindLevel(smallBlind: 2, bigBlind: 5),
  BlindLevel(smallBlind: 5, bigBlind: 10),
];

static final List<BlindLevel> defaultTournamentBlinds = [
  BlindLevel(smallBlind: 25, bigBlind: 50),
  BlindLevel(smallBlind: 50, bigBlind: 100),
  BlindLevel(smallBlind: 75, bigBlind: 150),
  BlindLevel(smallBlind: 100, bigBlind: 200),
  BlindLevel(smallBlind: 150, bigBlind: 300),
  BlindLevel(smallBlind: 200, bigBlind: 400),
  // ... etc
];
```

### 2. Dealer Session Inherits from Event

**When dealer starts session:**
```dart
static Future<DealerSession> startSession({
  required String clubId,
  required String tableId,
  // REMOVE: int smallBlind, int bigBlind  -- no longer dealer's choice
}) async {
  // Find active event for this table
  final event = await EventService.getActiveEventForTable(clubId, tableId);

  if (event == null) {
    throw 'No active event for this table. Ask admin to start the event.';
  }

  // Get current blind level from event
  final blindLevel = event.blindStructure[event.currentBlindLevelIndex];

  final session = DealerSession(
    // ...
    smallBlind: blindLevel.smallBlind,
    bigBlind: blindLevel.bigBlind,
    ante: blindLevel.ante,
    eventId: event.id,
    blindLevelIndex: event.currentBlindLevelIndex,
  );
}
```

### 3. Dealer "Blinds Up" Button

**Dealer can only advance blinds, not set them:**
```dart
Widget _buildBlindsUpButton() {
  return ElevatedButton.icon(
    icon: Icon(Icons.arrow_upward),
    label: Text('Blinds Up'),
    style: ElevatedButton.styleFrom(
      backgroundColor: PokerFriendColors.orange,
    ),
    onPressed: _isHandInProgress ? null : _advanceBlinds,
  );
}

Future<void> _advanceBlinds() async {
  // Advance event-wide blind level
  await EventService.advanceBlindLevel(
    clubId: _session.clubId,
    eventId: _session.eventId!,
  );

  // Local session will update via stream listener
}
```

### 4. Mid-Hand Blind Changes

**Track pending blind change:**
```dart
class DealerSession {
  // ... existing fields
  final int? pendingBlindLevelIndex;  // Set when blinds change mid-hand
}

// When advancing blinds
if (_isHandInProgress) {
  // Mark as pending - will apply after current hand
  await _firestore.doc(sessionRef).update({
    'pendingBlindLevelIndex': newLevelIndex,
  });
  _showSnackBar('New blinds will apply from next hand');
} else {
  // Apply immediately
  await _applyNewBlinds(newLevelIndex);
}

// When hand completes
Future<void> _onHandComplete() async {
  // Check for pending blind change
  if (_session.pendingBlindLevelIndex != null) {
    await _applyNewBlinds(_session.pendingBlindLevelIndex!);
  }
}
```

### 5. Sync Across All Tables/Dealers

**Watch event for blind changes:**
```dart
// In dealer_table_screen.dart initState
_eventSubscription = EventService.watchEvent(clubId, eventId).listen((event) {
  if (event == null) return;

  final newLevel = event.currentBlindLevelIndex;
  if (newLevel != _currentBlindLevelIndex) {
    if (_isHandInProgress) {
      // Queue for next hand
      setState(() => _pendingBlindLevel = newLevel);
      _showNotification('Blinds going up after this hand!');
    } else {
      // Apply immediately
      _applyNewBlinds(event.blindStructure[newLevel]);
    }
  }
});
```

### 6. Admin Controls

**Event dashboard for admin:**
```dart
Widget _buildBlindControl() {
  return Card(
    child: Column(
      children: [
        Text('Current Blinds: ${currentLevel.smallBlind}/${currentLevel.bigBlind}'),
        Text('Level ${currentLevelIndex + 1} of ${blindStructure.length}'),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: _advanceAllTables,
          child: Text('Advance Blinds (All Tables)'),
        ),
      ],
    ),
  );
}
```

---

## UI Changes

### Dealer Screen

**Remove:**
- Blind input fields on session start
- Manual blind adjustment

**Add:**
- Display current blinds (read-only)
- "Blinds Up" button (only advances to next level)
- "Next Level" preview
- Indicator when blinds are pending for next hand

### Create Event Screen (Admin)

**Add:**
- Blind structure editor
- Preset templates (home game, tournament standard, etc.)
- Option for timed auto-advance

---

## Related Files

- `lib/models/club_event.dart` - Add blindStructure, currentBlindLevelIndex
- `lib/models/dealer_session.dart` - Add pendingBlindLevelIndex
- `lib/services/dealer_service.dart` - Remove manual blind setting
- `lib/services/event_service.dart` - Add advanceBlindLevel()
- `lib/screens/dealer/dealer_table_screen.dart` - Blinds Up button, event sync
- `lib/screens/club/create_event_screen.dart` - Blind structure editor
- `lib/screens/club/event_detail_screen.dart` - Admin blind controls

---

## Migration Notes

- Existing sessions without eventId may need fallback behavior
- Consider allowing manual blinds for "quick start" without event (home games)

---

## Acceptance Criteria

- [ ] Dealer cannot manually set blind amounts
- [ ] Blinds automatically loaded from event settings
- [ ] Dealer has "Blinds Up" button to advance level
- [ ] Mid-hand blind changes apply from next hand
- [ ] All tables in event show same blind level
- [ ] Rotating dealers see consistent blinds
- [ ] Admin can advance blinds for all tables at once
- [ ] Blind change notification shown to dealers
