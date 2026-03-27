# Event Rankings Firestore Fallback Fix

**Date:** 2026-02-23
**Issue:** Event rankings showing nothing when admin plays as player

## Problem

When a club admin joins an event as a player and navigates from live hand logging back to EventDetailScreen → "View Live Rankings", the rankings screen shows nothing (empty state).

## Root Cause

Rankings were fetched **only from backend API** (`/api/v1/events/{eventId}/rankings`), but the backend only has player data if:
1. EventDashboardScreen was opened (triggers WebSocket sync)
2. Players were synced via `WebSocketService.syncEventPlayers()`

When viewing rankings directly without opening the dashboard first, the backend has no data.

## Solution

Added a Firestore fallback mechanism:

1. Try backend API first (existing behavior)
2. If empty/null, build rankings from Firestore seat data using `SeatService.getTableSeats()`

## Files Modified

| File | Changes |
|------|---------|
| `lib/services/event_service.dart` | Added `getRankingsFromFirestore()` method |
| `lib/screens/spectator/event_rankings_screen.dart` | Modified `_loadRankings()` to use fallback |

## Implementation Details

### EventService.getRankingsFromFirestore()

```dart
static Future<EventRankingsData?> getRankingsFromFirestore(
  String clubId,
  String eventId,
) async {
  // Get event and its tables
  // For each table, get seated players from SeatService
  // Build EventRanking objects with stack, rank, status
  // Sort by stack and assign ranks
  // Return EventRankingsData
}
```

### EventRankingsScreen._loadRankings()

```dart
// Try backend API first
var data = await EventService.getRankings(widget.event.id);

// Fallback to Firestore if backend returns empty
if (data == null || data.rankings.isEmpty) {
  data = await EventService.getRankingsFromFirestore(
    widget.event.clubId,
    widget.event.id,
  );
}
```

## Testing

1. Start an event as admin
2. Have dealer seat players at a table
3. Do NOT open EventDashboardScreen
4. Go to EventDetailScreen → "View Live Rankings"
5. Verify rankings show from Firestore data

## Notes

- Backend API remains primary source when available (more reliable for real-time via WebSocket)
- Firestore fallback ensures rankings always display if players are seated
- No backend changes required
