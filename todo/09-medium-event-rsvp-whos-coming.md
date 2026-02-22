# TODO: Display "Who's Coming" for Events with Auto-Reload

**Date:** 2026-02-21
**Branch:** feature/dealer-assisted-logging
**Status:** TODO (Feature Enhancement)
**Priority:** Medium

---

## Feature Description

Show a real-time list of players who have confirmed attendance for an event. This should be visible to all club members from the moment the event is created, and auto-refresh as players RSVP.

---

## Current Behavior

- Events show basic info (name, date, location, buy-in)
- No visibility into who is planning to attend
- No RSVP functionality

---

## Expected Behavior

- "Who's Coming" section visible on every event
- Players can RSVP (Going / Maybe / Not Going)
- List auto-refreshes in real-time
- Show count: "5 going, 2 maybe"
- Visible from event creation through completion

---

## Implementation Notes

### Data Model

**Add to ClubEvent or separate collection:**

```dart
// Option 1: Subcollection under event
// clubs/{clubId}/events/{eventId}/rsvps/{userId}
class EventRsvp {
  final String odPlayerId;
  final String odPlayerName;
  final String? photoUrl;
  final RsvpStatus status;  // going, maybe, notGoing
  final DateTime respondedAt;
}

enum RsvpStatus { going, maybe, notGoing }
```

**Or add to event document:**
```dart
class ClubEvent {
  // ... existing fields
  final Map<String, RsvpStatus> rsvps;  // odPlayerId -> status
}
```

### RSVP Service

```dart
class RsvpService {
  static Future<void> setRsvp({
    required String clubId,
    required String eventId,
    required RsvpStatus status,
  }) async {
    final userId = AuthService.userId;
    await _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('events')
        .doc(eventId)
        .collection('rsvps')
        .doc(userId)
        .set({
          'userId': odPlayerId,
          'userName': AuthService.userDisplayName,
          'photoUrl': AuthService.userPhotoUrl,
          'status': status.value,
          'respondedAt': FieldValue.serverTimestamp(),
        });
  }

  static Stream<List<EventRsvp>> watchRsvps(String clubId, String eventId) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('events')
        .doc(eventId)
        .collection('rsvps')
        .where('status', isEqualTo: 'going')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventRsvp.fromFirestore(doc))
            .toList());
  }
}
```

### UI Components

**RSVP Buttons:**
```dart
Widget _buildRsvpButtons(RsvpStatus? currentStatus) {
  return Row(
    children: [
      _RsvpButton(
        label: 'Going',
        icon: Icons.check_circle,
        isSelected: currentStatus == RsvpStatus.going,
        color: PokerFriendColors.green,
        onTap: () => _setRsvp(RsvpStatus.going),
      ),
      _RsvpButton(
        label: 'Maybe',
        icon: Icons.help_outline,
        isSelected: currentStatus == RsvpStatus.maybe,
        color: PokerFriendColors.yellow,
        onTap: () => _setRsvp(RsvpStatus.maybe),
      ),
      _RsvpButton(
        label: "Can't Go",
        icon: Icons.cancel_outlined,
        isSelected: currentStatus == RsvpStatus.notGoing,
        color: PokerFriendColors.red,
        onTap: () => _setRsvp(RsvpStatus.notGoing),
      ),
    ],
  );
}
```

**Who's Coming List:**
```dart
Widget _buildWhosComingSection(List<EventRsvp> rsvps) {
  final going = rsvps.where((r) => r.status == RsvpStatus.going).toList();
  final maybe = rsvps.where((r) => r.status == RsvpStatus.maybe).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Who's Coming",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 8),
      Text(
        '${going.length} going${maybe.isNotEmpty ? ', ${maybe.length} maybe' : ''}',
        style: TextStyle(color: PokerFriendColors.dark9),
      ),
      SizedBox(height: 12),
      // Avatar row for "going"
      _buildAvatarRow(going),
      if (maybe.isNotEmpty) ...[
        SizedBox(height: 8),
        Text('Maybe:', style: TextStyle(color: PokerFriendColors.dark9)),
        _buildAvatarRow(maybe),
      ],
    ],
  );
}

Widget _buildAvatarRow(List<EventRsvp> rsvps) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: rsvps.map((rsvp) => _buildPlayerChip(rsvp)).toList(),
  );
}

Widget _buildPlayerChip(EventRsvp rsvp) {
  return Chip(
    avatar: CircleAvatar(
      backgroundImage: rsvp.photoUrl != null
          ? NetworkImage(rsvp.photoUrl!)
          : null,
      child: rsvp.photoUrl == null
          ? Text(rsvp.playerName[0].toUpperCase())
          : null,
    ),
    label: Text(rsvp.playerName),
  );
}
```

### Real-Time Updates

```dart
// In event detail screen
StreamBuilder<List<EventRsvp>>(
  stream: RsvpService.watchRsvps(clubId, eventId),
  builder: (context, snapshot) {
    final rsvps = snapshot.data ?? [];
    return _buildWhosComingSection(rsvps);
  },
)
```

### Notification Integration

When players RSVP, optionally notify the event creator:
```dart
if (status == RsvpStatus.going) {
  await NotificationService.notifyEventCreator(
    eventId: eventId,
    message: '${userName} is coming to ${eventName}',
  );
}
```

---

## Where to Display

1. **Event Detail Screen** - Full list with RSVP buttons
2. **Event Card (in list)** - Small count badge: "5 going"
3. **Upcoming Events Widget** - Preview of who's coming

---

## Related Files

- `lib/models/club_event.dart` - Add RSVP data or create new model
- `lib/screens/club/event_detail_screen.dart` - Display and RSVP UI
- `lib/screens/club/events_screen.dart` - Show count on event cards
- `lib/services/event_service.dart` - Or create `rsvp_service.dart`

---

## Edge Cases

1. **Event at capacity**: Show "Full" and maybe waitlist
2. **Player changes RSVP**: Update in real-time
3. **Event cancelled**: Clear/archive RSVPs
4. **Private events**: Only show RSVPs to members

---

## Acceptance Criteria

- [ ] Players can RSVP as Going / Maybe / Can't Go
- [ ] "Who's Coming" section shows on event detail
- [ ] List updates in real-time without manual refresh
- [ ] Going count visible on event cards in list view
- [ ] Shows player names and avatars
- [ ] Works from event creation through event completion
- [ ] Current user's RSVP status is highlighted
