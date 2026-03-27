# Busted Player Display Fix in Live Rankings

**Date:** 2026-02-22
**Branch:** feature/dealer-assisted-logging
**Status:** COMPLETED

---

## Problem

Busted players (stack = 0) in the Live Rankings spectator screen were displaying incorrectly:
- Table/seat info was still showing (e.g., "1 - Seat 7")
- No "BUSTED" label
- Badge showed "X" instead of finish position (e.g., "9th")
- Name had strikethrough (user didn't want this)

---

## Root Cause

**Wrong file was being modified!**

The bug was in `lib/screens/spectator/event_rankings_screen.dart` (the "Live Rankings" screen for spectators), but we were modifying `lib/screens/club/event_dashboard_screen.dart` (the admin dashboard).

The files have similar names and similar code structure, which caused confusion.

### How to identify the correct file in the future:
- The spectator screen shows "Live Rankings" as the title with the event name below it
- The admin dashboard shows the event name as the AppBar title
- Search for unique UI text like "Live Rankings" to find the right file

---

## The Actual Bug

In `event_rankings_screen.dart`, the `_buildRankingCard` method:

1. **Table/seat was shown unconditionally:**
```dart
// BUG: No check for isEliminated
if (ranking.tableId.isNotEmpty || ranking.seatNumber > 0) ...[
  Text('${_getTableDisplayName(ranking)} - Seat ${ranking.seatNumber}'),
]
```

2. **No BUSTED label** - simply wasn't implemented

3. **No finish position calculation** - `ranking.finishPosition` was null because the data source didn't provide it

---

## Solution

### 1. Hide table/seat for eliminated players
```dart
if (!isEliminated && (ranking.tableId.isNotEmpty || ranking.seatNumber > 0)) ...[
  // ... table/seat text
]
```

### 2. Add BUSTED label
```dart
if (isEliminated) ...[
  Text('BUSTED', style: TextStyle(color: PokerFriendColors.red, ...)),
]
```

### 3. Calculate finish position client-side
```dart
// In _buildRankingsList:
final totalPlayers = rankings.length;
final eliminatedPlayers = rankings.where((r) => r.isEliminated).toList();

final calculatedFinishPositions = <String, int>{};
for (int i = 0; i < eliminatedPlayers.length; i++) {
  final player = eliminatedPlayers[i];
  if (player.finishPosition == null) {
    calculatedFinishPositions[player.playerId] = totalPlayers - i;
  }
}
```

### 4. Remove strikethrough from name
Changed from `decoration: isEliminated ? TextDecoration.lineThrough : null` to just using gray color.

---

## Files Modified

- `lib/screens/spectator/event_rankings_screen.dart` - Main fix
- `lib/screens/club/event_dashboard_screen.dart` - Cleanup of unnecessary diagnostic logs

---

## Key Lessons

1. **Always verify you're editing the correct file** - Search for unique UI text to confirm
2. **Multiple screens can have similar functionality** - Dashboard vs Spectator view
3. **Client-side calculation is needed when server doesn't provide data** - finishPosition wasn't being tracked server-side

---

## Testing

1. Start a tournament with test players
2. Have one player go bust (stack = 0)
3. Open Live Rankings screen (spectator view)
4. Verify:
   - Badge shows finish position number (e.g., "9")
   - No table/seat info shown
   - "BUSTED" label in red
   - Name in gray (no strikethrough)
   - 0 chips displayed
