# TODO: Live Rankings Lifecycle - When to Reset/Clear?

**Date:** 2026-02-21
**Branch:** feature/dealer-assisted-logging
**Status:** COMPLETED
**Priority:** High

---

## Problem Statement

The current live rankings behavior feels inconsistent:

1. Dealer runs session → rankings show players and stacks
2. Dealer stops session → rankings persist (correct - wait for admin to finish event)
3. Dealer reopens same table with NEW players → old rankings still show
4. Only after new hand completes do rankings update

This creates a confusing state where stale data is displayed.

---

## Current Behavior

```
Event Started
    ↓
Dealer Session 1 → Rankings: [Player A: 15000, Player B: 12000]
    ↓
Dealer Stops Session
    ↓
Rankings still show: [Player A: 15000, Player B: 12000]  ← OK, event still active
    ↓
Dealer Starts Session 2 (same table, different players)
    ↓
Rankings STILL show: [Player A: 15000, Player B: 12000]  ← STALE!
    ↓
New hand completes
    ↓
Rankings finally update: [Player C: 20000, Player D: 8000]
```

---

## The Core Question

**What is the "source of truth" for live rankings?**

- Is it the **event** (rankings persist across sessions)?
- Is it the **active sessions** (rankings reset when sessions end)?
- Is it **real-time seat state** (rankings reflect current seated players)?

---

## Design Options

### Option 1: Rankings = Active Sessions Only

Rankings only show players who are in an **active dealer session**.

```
Session ends → Player removed from rankings
Session starts → Player added when first hand dealt
```

**Pros:**
- Clear and predictable
- No stale data
- Rankings always reflect "who's playing right now"

**Cons:**
- During breaks, rankings disappear
- Can't see final standings after last session ends

**Implementation:**
```dart
// Only include players from active sessions
final activeSessions = await getActiveSessions(eventId);
final rankings = activeSessions
    .expand((s) => s.players.values)
    .toList();
```

---

### Option 2: Rankings Persist Until Event Ends

Rankings accumulate throughout event. Only cleared when admin finishes event.

```
Session ends → Players remain in rankings (frozen stacks)
New session → New players added, old players remain
Event ends → Rankings cleared
```

**Pros:**
- Historical view of all participants
- Good for multi-session events

**Cons:**
- Stale players mixed with active players
- Confusing when tables reset

**Current behavior (partially)**

---

### Option 3: Rankings = Current Seat State

Rankings reflect who is **currently seated** across all event tables.

```
Player seated → Added to rankings
Player removed from seat → Removed from rankings
Stack changes → Rankings update immediately
```

**Pros:**
- Always accurate
- Real-time reflection of table state
- No stale data ever

**Cons:**
- Need to sync rankings with seat service
- More complex implementation

**Implementation:**
```dart
// Watch all seats for event tables
Stream<List<PlayerRanking>> watchEventRankings(String eventId) {
  final event = await getEvent(eventId);

  return CombineLatestStream.list(
    event.tableIds.map((tableId) =>
      SeatService.watchTableSeats(event.clubId, tableId)
    ),
  ).map((allTableSeats) {
    // Flatten and convert to rankings
    return allTableSeats
        .expand((seats) => seats.values)
        .where((seat) => seat.isOccupied)
        .map((seat) => PlayerRanking(
          playerId: seat.playerId,
          name: seat.playerName,
          stack: seat.chipStack,
          tableId: seat.tableId,
        ))
        .toList()
        ..sort((a, b) => b.stack.compareTo(a.stack));
  });
}
```

---

### Option 4: Explicit "Tournament Mode" vs "Cash Game Mode"

Different behavior based on game type:

**Tournament Mode:**
- Rankings persist until event ends
- Busted players marked as "OUT" but stay in rankings
- Final standings preserved

**Cash Game Mode:**
- Rankings only show currently seated players
- Player leaves → removed from rankings
- No historical tracking needed

**Pros:**
- Matches real-world expectations
- Tournament needs final standings
- Cash game is fluid

**Implementation:**
```dart
if (event.gameType == 'tournament') {
  // Option 2: Persist until event ends
} else {
  // Option 3: Real-time seat state
}
```

---

### Option 5: Admin "Snapshot" Control

Admin can take "snapshots" of rankings at key moments.

```
During event → Live rankings (real-time seat state)
Admin clicks "Save Standings" → Snapshot preserved
Admin clicks "Reset Rankings" → Clear for new session
Event ends → Final snapshot becomes permanent record
```

**Pros:**
- Maximum flexibility
- Admin controls the narrative
- Good for multi-day events or rebuys

**Cons:**
- More admin overhead
- Could forget to snapshot

---

## Recommended Approach

**Option 4 (Tournament vs Cash) + Option 3 (Seat State) hybrid:**

### For Cash Games:
- Rankings = currently seated players with stacks
- Player leaves seat → removed from rankings
- Real-time, no persistence needed

### For Tournaments:
- Rankings = all players who have participated
- Busted players (stack = 0) marked as "BUSTED" with finish position
- Active players show current stack from seat state
- Admin "Finish Event" freezes final standings

### Session Reset Handling:

When a new session starts on a table that had a previous session:

```dart
// When starting new session
if (event.gameType == 'tournament') {
  // Keep existing rankings, new players will be added
  // This is a continuation of the tournament
} else {
  // Cash game: rankings are real-time seat state
  // Old session data is irrelevant
  // Rankings auto-update when new players seated
}
```

### Clear Distinction in UI:

```dart
Widget _buildRankingsHeader() {
  return Row(
    children: [
      Text(event.gameType == 'tournament' ? 'Tournament Standings' : 'Table Leaderboard'),
      if (event.gameType == 'cash')
        Chip(label: Text('LIVE'), backgroundColor: Colors.green),
    ],
  );
}
```

---

## Implementation Steps

1. **Decide on the approach** (need your input!)

2. **Update rankings source:**
   - Tournament: Aggregate from session history + active seats
   - Cash: Real-time seat state only

3. **Handle session transitions:**
   - Clear stale session data when new session starts (for cash)
   - Preserve and merge data (for tournament)

4. **Add UI indicators:**
   - Show "LIVE" vs "FINAL" state
   - Show "BUSTED" for eliminated players
   - Indicate last update time

---

## Questions to Answer

1. **Should rankings show during breaks?** (no active sessions)
   - Yes: Keep last known state
   - No: Show "On Break" message

2. **What happens to a player who leaves and rejoins?**
   - Tournament: Same player, continuous tracking
   - Cash: Treated as new session

3. **Multi-table tournaments - player moves tables?**
   - Rankings should follow player, not table

4. **Should there be a "spectator" vs "admin" view?**
   - Admin sees more detail, controls
   - Spectator sees clean standings

---

## Related Files

- `lib/services/event_service.dart` - Rankings calculation
- `lib/screens/club/event_dashboard_screen.dart` - Rankings display
- `lib/services/dealer_service.dart` - Session lifecycle
- `lib/services/seat_service.dart` - Real-time seat state

---

## Acceptance Criteria

- [ ] Design decision made on rankings lifecycle
- [ ] Cash games: rankings reflect current seat state in real-time
- [ ] Tournaments: rankings persist with proper status (active/busted)
- [ ] No stale data shown from old sessions
- [ ] Clear UI indication of rankings state (live/final/on break)
- [ ] Admin can view final standings after event ends
