# Club Events and Session Break/Pause System

**Priority:** Medium (Future)
**Created:** 2026-02-17

---

## Overview

Players will subscribe to clubs, and club admins can organize events that span multiple tables/sessions. When an admin pauses an event (e.g., for a break), all players should see this status in real-time.

---

## Current State

- `DealerSession` already has `status` field: `active`, `paused`, `ended`
- Player Session Screen will watch session status changes
- Pause overlay infrastructure will be in place

---

## Future Schema Extension

```
clubs/{clubId}
  - name: string
  - ownerId: string
  - memberIds: [string]

clubs/{clubId}/events/{eventId}
  - name: "Friday Night Tournament"
  - status: 'active' | 'paused' | 'break' | 'ended'
  - breakMessage: "15 minute break - back at 8:00 PM"
  - startTime: timestamp
  - endTime: timestamp
  - sessions: [sessionId1, sessionId2]  // Multiple tables

dealer_sessions/{sessionId}
  - eventId: string (optional, links to club event)
  - status: 'active' | 'paused' | 'ended'
```

---

## Features to Implement

### 1. Club Subscriptions
- [ ] Players can join/subscribe to clubs
- [ ] Club member management UI
- [ ] Club discovery/search

### 2. Event Management
- [ ] Club admins can create events
- [ ] Events can span multiple tables
- [ ] Event status independent of individual session status

### 3. Break/Pause System
- [ ] Admin can pause entire event (all tables)
- [ ] Custom break messages
- [ ] Countdown timer for break end
- [ ] Players see pause overlay with message

### 4. Real-time Status Sync
- [ ] All players see event status changes
- [ ] Smooth transition animations
- [ ] Sound/vibration notification for break start/end

---

## Architecture Notes

The Player Session Screen should be designed to:
1. Watch both `session.status` AND future `event.status`
2. Show appropriate overlay based on status
3. Handle nested status (event paused overrides session active)

```dart
// Future: Watch event status in addition to session
Stream<String> _getEffectiveStatus() {
  // If event exists and is paused, show event pause
  // Otherwise show session status
}
```

---

## Implementation Order (When Ready)

1. Club subscription model
2. Event creation and management
3. Event-level pause functionality
4. Player UI for break display
5. Admin UI for break controls

---

## Notes

- Keep DealerSession independent - events wrap sessions
- Allow sessions without events (backwards compatible)
- Consider timezone handling for break end times
