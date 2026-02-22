# TODO: Event Finish = Global Shutdown for All Sessions

**Date:** 2026-02-21
**Branch:** feature/dealer-assisted-logging
**Status:** TODO (Bug Fix)
**Priority:** High

---

## Problem Statement

When club admin clicks "Finish Event", it should trigger a complete shutdown:
- All dealer sessions for that event must end
- All player sessions must be saved correctly
- Dealer screens should exit or show "Event Ended"
- Player screens should show "Session Ended"

Currently, the event finishes for players but dealers remain in their session.

---

## Current Behavior

```
Admin clicks "Finish Event"
    ↓
Event status → 'completed'
    ↓
Player screens detect event ended → Show "Session Ended" ✓
    ↓
Dealer screens → STILL ACTIVE, no notification ✗
    ↓
Dealer session → STILL RUNNING, not saved ✗
    ↓
Player session records → May not be saved properly ✗
```

---

## Expected Behavior

```
Admin clicks "Finish Event"
    ↓
Event status → 'completed'
    ↓
All dealer sessions for event → status: 'ended'
    ↓
All player session records → created/saved
    ↓
Dealer screens → Exit to event screen with "Event Finished" message
    ↓
Player screens → Show "Session Ended" dialog
    ↓
Live rankings → Frozen as "Final Standings"
```

---

## Implementation Notes

### 1. Update EventService.completeEvent()

Currently in `event_service.dart`, there's `_endEventDealerSessions()` but it might not be working correctly:

```dart
static Future<void> completeEvent(String clubId, String eventId) async {
  // 1. End all active dealer sessions for this event
  await _endAllEventSessions(eventId);

  // 2. Update event status
  await updateEvent(clubId, eventId, status: EventStatus.completed);

  // 3. Save final rankings snapshot (optional)
  await _saveFinalRankings(clubId, eventId);
}

static Future<void> _endAllEventSessions(String eventId) async {
  try {
    // Find ALL sessions for this event (active, paused, etc.)
    final sessions = await _firestore
        .collection('dealer_sessions')
        .where('eventId', isEqualTo: eventId)
        .where('status', whereIn: [
          DealerSessionStatus.active.value,
          DealerSessionStatus.paused.value,
        ])
        .get();

    print('Found ${sessions.docs.length} active sessions to end for event $eventId');

    for (final doc in sessions.docs) {
      try {
        // This should:
        // - Set session status to 'ended'
        // - Create poker_sessions records for each player
        // - Clear seats
        // - Clear table session info
        await DealerService.endSession(doc.id);
        print('Ended session ${doc.id}');
      } catch (e) {
        print('Error ending session ${doc.id}: $e');
        // Force status update even if full cleanup fails
        await _firestore
            .collection('dealer_sessions')
            .doc(doc.id)
            .update({
              'status': DealerSessionStatus.ended.value,
              'endTime': FieldValue.serverTimestamp(),
            });
      }
    }
  } catch (e) {
    print('Error ending event sessions: $e');
  }
}
```

### 2. Dealer Screen: Watch Event Status

Dealer screen should listen for event completion:

```dart
// In dealer_table_screen.dart initState
_eventSubscription = EventService.watchEvent(
  _session.clubId,
  _session.eventId!,
).listen((event) {
  if (event == null || event.status == EventStatus.completed || event.status == EventStatus.cancelled) {
    _handleEventEnded(event?.status);
  }
});

void _handleEventEnded(EventStatus? status) {
  // Stop any ongoing operations
  _stopVoiceRecognition();
  _sessionSubscription?.cancel();

  // Show dialog and exit
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(status == EventStatus.cancelled ? 'Event Cancelled' : 'Event Finished'),
      content: Text(
        status == EventStatus.cancelled
            ? 'The club admin has cancelled this event.'
            : 'The club admin has finished this event. All sessions have been saved.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pop(context); // Exit dealer screen
          },
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

### 3. Dealer Screen: Also Watch Session Status

In case session is ended directly (not via event):

```dart
_sessionSubscription = DealerService.watchSession(_sessionId).listen((session) {
  if (session == null || session.status == DealerSessionStatus.ended) {
    if (!_isShowingExitDialog) {
      _showSessionEndedDialog();
    }
  }
});
```

### 4. Verify Player Session Records Are Created

Ensure `DealerService.endSession()` creates records for ALL players:

```dart
static Future<void> endSession(String sessionId) async {
  final sessionDoc = await _firestore
      .collection(_dealerSessionsCollection)
      .doc(sessionId)
      .get();

  if (!sessionDoc.exists) throw 'Session not found';

  final session = DealerSession.fromFirestore(sessionDoc);
  final endTime = DateTime.now();

  // CRITICAL: Create poker_sessions records for each player BEFORE updating status
  for (final entry in session.players.entries) {
    final player = entry.value;
    // Only create for real users who actually played
    if (player.playerId.isNotEmpty &&
        !player.playerId.startsWith('manual_') &&
        player.isActive) {  // Make sure they participated
      try {
        await _createPlayerSessionRecord(
          dealerSession: session,
          sessionId: sessionId,
          playerId: player.playerId,
          playerName: player.displayName,
          seatNumber: entry.key,
          endTime: endTime,
        );
        print('Created session record for player ${player.displayName}');
      } catch (e) {
        print('Error creating session record for ${player.playerId}: $e');
      }
    }
  }

  // Now update session status
  await _firestore
      .collection(_dealerSessionsCollection)
      .doc(sessionId)
      .update({
        'status': DealerSessionStatus.ended.value,
        'endTime': FieldValue.serverTimestamp(),
      });

  // Clear seats and table
  await SeatService.clearAllSeats(clubId: session.clubId, tableId: session.tableId);
  await TableService.clearTableSession(session.clubId, session.tableId);
}
```

### 5. Handle Edge Cases

**Mid-hand shutdown:**
```dart
static Future<void> _endAllEventSessions(String eventId) async {
  // ...
  for (final doc in sessions.docs) {
    final session = DealerSession.fromFirestore(doc);

    // If there's an active hand, complete it first
    if (session.currentHandId != null) {
      try {
        // Mark hand as incomplete/cancelled
        await _firestore
            .collection('dealer_sessions')
            .doc(doc.id)
            .collection('hands')
            .doc(session.currentHandId)
            .update({
              'status': 'cancelled',
              'endTime': FieldValue.serverTimestamp(),
              'note': 'Event ended mid-hand',
            });
      } catch (e) {
        print('Error cancelling mid-hand: $e');
      }
    }

    await DealerService.endSession(doc.id);
  }
}
```

**Multiple tables:**
```dart
// Ensure all tables in event are processed
final event = await getEvent(clubId, eventId);
for (final tableId in event.tableIds) {
  await TableService.clearTableSession(clubId, tableId);
}
```

---

## Verification Checklist

When admin finishes event:

- [ ] All dealer sessions status → 'ended'
- [ ] All dealer screens show "Event Finished" and exit
- [ ] All player screens show "Session Ended"
- [ ] poker_sessions records created for every player
- [ ] Session records have correct:
  - [ ] sessionName (from event name)
  - [ ] gameType (from event)
  - [ ] totalHands count
  - [ ] startTime / endTime
- [ ] All table seats cleared
- [ ] All table currentSessionId cleared
- [ ] Live rankings frozen (or marked as final)

---

## Testing Scenarios

1. **Single table, single dealer:**
   - Admin finishes → dealer exits, players get records

2. **Multiple tables, multiple dealers:**
   - Admin finishes → ALL dealers exit, ALL players get records

3. **Mid-hand finish:**
   - Hand marked cancelled, session still saved properly

4. **Dealer already stopped, admin finishes:**
   - No duplicate processing, clean finish

5. **Player left early, admin finishes:**
   - Player who left should already have record (from when dealer removed them)

---

## Related Files

- `lib/services/event_service.dart` - completeEvent(), _endEventDealerSessions()
- `lib/services/dealer_service.dart` - endSession(), _createPlayerSessionRecord()
- `lib/screens/dealer/dealer_table_screen.dart` - Event status watcher
- `lib/screens/player/player_session_screen.dart` - Session/event end detection

---

## Acceptance Criteria

- [ ] Admin "Finish Event" ends ALL dealer sessions for that event
- [ ] All dealers see "Event Finished" dialog and exit to event screen
- [ ] All players see "Session Ended" dialog
- [ ] All players have session records saved with correct data
- [ ] No orphaned sessions left in 'active' status
- [ ] Works for single and multi-table events
- [ ] Mid-hand scenarios handled gracefully
