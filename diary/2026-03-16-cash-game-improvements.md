# Cash Game Improvements

**Date:** 2026-03-16

## Issues Fixed

### 1. Event Card Player Count Not Updating for Cash Games

**Problem:** Event card on club dashboard showed "0 playing" for cash games even when players were seated.

**Root Cause:** `_loadPlayerCounts()` in `club_dashboard_screen.dart` used `EventService.getRankingsFromFirestore()` for all live events, which only works for tournaments (checks `PlayerRankingStatus.active`). Cash games don't have tournament rankings.

**Fix:**
- Check `event.gameType` and handle cash games differently
- For cash games: Count seats using `SeatService.getTableSeats()` where `isOccupied == true`
- For tournaments: Continue using existing rankings logic

**File:** `lib/screens/club/club_dashboard_screen.dart`

### 2. Real-Time Player Count Updates for Cash Games

**Problem:** Player count didn't update in real-time when seats changed.

**Fix:**
- Added `_seatSubscriptions` map to track Firestore listeners for cash game tables
- Added `_setupSeatListeners()` to set up real-time listeners when live events change
- Added `_updateCashGamePlayerCount()` to recalculate count when seats change
- Clean up subscriptions in `dispose()`

**File:** `lib/screens/club/club_dashboard_screen.dart`

### 3. Seat Notification Improvements

**Problem:**
- Notification showed tableId (UUID) instead of table number
- Notification was cluttered with stack info
- Clicking notification went to player session (realtime hand logging) instead of event details

**Fix:**
- Simplified notification to show: "You're seated, good luck!" with "Table X, Seat #Y"
- Removed stack info from notification
- Changed navigation to go to EventDetailScreen instead of player session

**File:** `lib/screens/home_screen.dart`

**Before:**
```
You've Been Seated!
Table: 90CkiTdubGoLKwqsx5Q4
Seat #8 • Stack: Not set
```

**After:**
```
You're seated, good luck!
Table 1, Seat #8
```

## Files Modified

| File | Changes |
|------|---------|
| `lib/screens/club/club_dashboard_screen.dart` | Cash game player count + real-time updates |
| `lib/screens/home_screen.dart` | Simplified seat notification + event details navigation |

## Testing

1. Create cash game event → start it → add players → verify player count shows correctly
2. Add/remove players → verify count updates in real-time
3. Get seated as player → verify notification shows "Table X, Seat #Y"
4. Tap notification → verify navigates to event details page
