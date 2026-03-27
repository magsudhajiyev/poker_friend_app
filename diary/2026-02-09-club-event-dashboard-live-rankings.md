# Club Event Dashboard with Live Rankings

**Date:** 2026-02-09
**Feature:** Real-time leaderboard dashboard for poker clubs

---

## Overview

Implemented a live ranking dashboard for poker clubs that displays player rankings based on chip counts. The dashboard updates in real-time as dealers log actions and stack changes across multiple tables.

## Key Requirements

1. **Event Scope**: Club can select which tables are part of an event (multiple events can run in parallel)
2. **Ranking Basis**: Current chip count
3. **Visibility**: Club configures access - private or public (for venue TV display)
4. **Real-time Updates**: Rankings update after each hand or every 30 seconds

---

## Files Created

### Flutter (poker_logger)

| File | Purpose |
|------|---------|
| `lib/models/club_event.dart` | ClubEvent model with EventStatus enum |
| `lib/models/event_ranking.dart` | EventRanking and EventRankingsData models |
| `lib/services/event_service.dart` | API service for event CRUD and rankings |
| `lib/screens/club/event_management_screen.dart` | Create/manage events UI |
| `lib/screens/club/event_dashboard_screen.dart` | Live rankings dashboard |
| `lib/screens/public/public_leaderboard_screen.dart` | Full-screen TV display mode |

### Backend (poker_friend_ai)

| File | Purpose |
|------|---------|
| `app/services/event_manager.py` | In-memory event tracking with player rankings |
| `app/services/ranking_service.py` | Ranking calculation and WebSocket broadcasting |
| `app/api/routes/events.py` | REST API endpoints for events |

### Modified Files

| File | Changes |
|------|---------|
| `lib/services/websocket_service.dart` | Added event room methods (joinEvent, leaveEvent, syncEventPlayers, emitPlayerStackUpdate) |
| `lib/screens/dealer/dealer_table_screen.dart` | Emit stack updates after hand completion |
| `lib/screens/dealer/dealer_home_screen.dart` | Added Events navigation button |
| `app/websocket/events.py` | Added event handlers (join_event, leave_event, sync_event_players, update_player_stack) |
| `app/main.py` | Registered events router |

---

## Issues Encountered & Solutions

### Issue 1: Event Not Found on Backend

**Problem:** Dashboard showed "Disconnected" because the HTTP POST to register the event was failing silently, and the WebSocket `join_event` returned "Event not found".

**Solution:** Modified WebSocket handlers (`join_event`, `sync_event_players`) to accept optional event data and create the event on-the-fly if it doesn't exist. Flutter now passes full event data when joining.

```python
# Backend: Create event on-the-fly if not found
if not event:
    if club_id and name:
        event = event_manager.create_event(...)
```

### Issue 2: Player ID Mismatch

**Problem:** Dashboard synced players with IDs like `manual_1234567890` but dealer stack updates used different IDs, causing "Player not found" errors.

**Solution:** Standardized player IDs to seat-based format: `seat_{tableId}_{seatNumber}`. Both dashboard sync and dealer updates now use this consistent format.

### Issue 3: Rankings Not Auto-Updating

**Problem:** Dashboard only updated on manual refresh, not after hands completed.

**Solution:** Implemented two auto-update mechanisms:
1. **Periodic refresh (30 seconds)**: Timer in dashboard that syncs player data
2. **Real-time updates**: Dealer emits `update_player_stack` after each hand, backend broadcasts `ranking_update` to event room

### Issue 4: Player Not Found During Stack Update

**Problem:** When dealer updated a player's stack, if the player wasn't synced to the event yet, the update failed.

**Solution:** Modified `ranking_service.handle_stack_change()` to add the player if not found, extracting seat number from the player ID.

---

## Architecture

### Real-Time Flow

```
Dealer completes hand
    ↓
_updateSeatChipStacks() called
    ↓
For each active player:
  1. SeatService.updateChipStack() → Firebase
  2. WebSocketService.emitPlayerStackUpdate() → Backend
    ↓
Backend: update_player_stack handler
    ↓
Check: Is table in active event?
    ↓ (yes)
ranking_service.handle_stack_change()
    ↓
Update player stack (or add player if new)
    ↓
broadcast_ranking_update() → event room
    ↓
Dashboard receives 'ranking_update' event
    ↓
UI updates with new rankings
```

### WebSocket Events

| Event | Direction | Purpose |
|-------|-----------|---------|
| `join_event` | Client → Server | Join event room, optionally create event |
| `leave_event` | Client → Server | Leave event room |
| `sync_event_players` | Client → Server | Sync all players from tables |
| `update_player_stack` | Client → Server | Update single player's stack |
| `ranking_update` | Server → Client | Broadcast updated rankings |

### Data Models

**ClubEvent (Flutter)**
```dart
class ClubEvent {
  final String id;
  final String clubId;
  final String name;
  final List<String> tableIds;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isPublic;
  final String? accessCode;
  final EventStatus status;  // active, paused, completed
  final String createdBy;
}
```

**PlayerRanking (Backend)**
```python
@dataclass
class PlayerRanking:
    player_id: str
    player_name: str
    current_stack: int
    starting_stack: int
    table_id: str
    table_name: Optional[str]
    seat_number: int
    rank: int
    previous_rank: Optional[int]
    previous_stack: Optional[int]
```

---

## Firestore Structure

```
clubs/{clubId}/events/{eventId}/
  name, tableIds[], isPublic, accessCode, status, startTime, endTime, createdBy
```

---

## Usage

1. **Create Event**: Dealer Home → Events → New Event → Select tables → Create
2. **View Dashboard**: Tap on active event card
3. **TV Display**: Dashboard → Fullscreen icon (top right)
4. **Share**: Event card → Share button (copies public URL)

---

## Key Learnings

1. **Consistent IDs are crucial**: When multiple systems track the same entity, use a predictable ID format (seat-based IDs work well for poker)

2. **Graceful fallbacks**: Backend should handle missing data gracefully - create entities on-the-fly when possible rather than failing

3. **Multiple update mechanisms**: Combine real-time WebSocket updates with periodic polling for reliability

4. **Server restart required**: Python backend changes require server restart - easy to forget during development

---

## Future Improvements

- [ ] Persist events in backend (currently in-memory only)
- [ ] Show stack change animations on dashboard
- [ ] Add player elimination tracking
- [ ] Support for tournament blind level display
- [ ] Historical rankings/graphs
