# Cash Game Grouping: Double-Seating Prevention, Waitlist Consolidation, Alphanumeric Table Sort

**Date**: 2026-04-12
**Status**: Confirmed working

---

## Overview

Three polish fixes for the grouped cash game flow (introduced for Figma node `1213:8244`). All three are tightly related to the "one stakes, one waitlist, one source of truth" model that the grouped screen is built on:

1. **Prevent admins from double-seating a club member.** Previously an admin could seat the same player at multiple seats across multiple running tables. Now already-seated members are greyed out in the Select Member list with an inline "Table N · Seat M" label, and a defensive write-path guard catches race conditions.
2. **Consolidate the cash game waitlist.** The per-table member view had its own Join Waitlist button that wrote to a per-event waitlist, which conflicted with the grouped screen's stakes-scoped waitlist. Players could end up in two waitlists at once. Fix: removed the waitlist UI entirely from the per-table view — the grouped cash game screen is now the sole place to join/leave the stakes waitlist.
3. **Sort tables alphanumerically in the grouped grid.** The 2×N grid was ordering tables by event name first (reflecting event creation order), producing orderings like "Table 3, Table 1, Table 2" when one event had been created before another. Now tables sort purely by `tableNumber`, so the grid always reads Table 1, Table 2, Table 3, ….

---

## Files Changed (4 files)

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/services/seat_service.dart` | **Modified** | New `watchClubSeatedAssignments` stream for all joined seats in a club |
| `lib/screens/club/admin_table_management_screen.dart` | **Modified** | Double-seating prevention: new state, UI disabling, write-path guard |
| `lib/screens/club/member_table_view_screen.dart` | **Modified** | Stripped all waitlist state/UI — read-only table viewer |
| `lib/screens/club/grouped_cash_game_screen.dart` | **Modified** | Both `tables.sort` sites now sort purely by `tableNumber` |

---

## Problem 1 — Admin Could Double-Seat a Member

### Symptom

An admin opens Table 2 → Select Member → picks Alice → Alice is seated. Then admin opens Table 1 → Select Member → Alice still appears in the list, enabled, with no indication she's already seated. Admin picks her again → she's now in two seats across two tables. Every list read is a fresh query per-table, so nothing warned the admin that Alice was elsewhere in the club.

This is a use-case bug, not a data corruption bug — the writes succeed because nothing in the seat-assignment path checks for existing seats in other tables.

### Root Cause

`_MemberSearchSheet` inside `admin_table_management_screen.dart` only knew about:

- The list of club members (from `ClubService.getMembers`)
- The seats of the **current** table (from the screen's `_seats` map)

Members seated at *other* tables in the same club were invisible to the sheet.

### Fix

**Step 1 — Club-wide seats stream.** Added a new method on `SeatService`:

```dart
// lib/services/seat_service.dart
static Stream<List<SeatAssignment>> watchClubSeatedAssignments({
  required String clubId,
}) {
  return _firestore
      .collection(_seatAssignmentsCollection)
      .where('clubId', isEqualTo: clubId)
      .where('status', isEqualTo: 'joined')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map(SeatAssignment.fromFirestore).toList());
}
```

The `status == 'joined'` filter reuses the canonical value that `SeatAssignment.toFirestore()` writes, and since `SeatAssignment._parseStatusWithPlayerId` also treats legacy records without a status field (but with a `playerId`) as joined, we catch older rows too.

**Step 2 — Watch it in the admin screen.** Added three new pieces of state to `_AdminTableManagementScreenState`:

```dart
List<PokerTable> _clubTables = [];
List<SeatAssignment> _clubSeatedAssignments = [];
StreamSubscription? _clubSeatsSubscription;
```

`_loadData` now fetches `TableService.getTables(widget.club.id)` in parallel with the existing table fetch. `_setupListeners` subscribes to the new stream and updates `_clubSeatedAssignments` on every snapshot. `dispose()` cancels the subscription.

**Step 3 — Build a userId → "Table N · Seat M" map.** New helper:

```dart
Map<String, String> _buildSeatedInfoByUserId() {
  final byTableId = { for (final t in _clubTables) t.id: t };
  // Fallback in case _clubTables hasn't loaded yet
  if (_table != null && !byTableId.containsKey(_table!.id)) {
    byTableId[_table!.id] = _table!;
  }
  final result = <String, String>{};
  for (final a in _clubSeatedAssignments) {
    final playerId = a.playerId;
    if (playerId == null) continue;
    final table = byTableId[a.tableId];
    final tableLabel = table != null
        ? 'Table ${table.tableNumber}'
        : 'Another table';
    result[playerId] = '$tableLabel · Seat ${a.seatNumber}';
  }
  return result;
}
```

**Crucial subtlety**: the first draft of this helper had `if (a.tableId == widget.tableId) continue;` to "allow reseating within the same table". This completely broke the feature: if admin is currently on Table 2 and all 8 seated members are on Table 2, every row gets skipped and the map ends up empty. Fix: **never** skip the current table — just include every joined assignment in the club. If the user is already on the current table at a different seat, the guard is still correct (we want to block moving them via this flow).

**Step 4 — Thread the map into the sheet.** Both `_SeatPlayerSheet` and `_MemberSearchSheet` gained a `final Map<String, String> seatedInfoByUserId;` field. The admin screen rebuilds the map each time it opens the sheet, so the disabled state reflects live seat state at the moment the sheet opens.

**Step 5 — Disable the rows.** In `_MemberSearchSheet.build`:

- Members are sorted so seated ones sink to the bottom of the list.
- Each seated row is wrapped in `Opacity(opacity: 0.45)`.
- `ListTile.enabled = !isSeated` and `onTap = isSeated ? null : ...`.
- Subtitle shows the mint-colored `"Table N · Seat M"` label in `Color(0xFF89F1EC)`.
- Trailing `Icons.event_seat` icon in the same mint color.

**Step 6 — Defensive write-path guard.** Even with the UI blocking taps, a stale stream or a race could theoretically let a write through. Added an explicit check at the top of `_seatMember`:

```dart
final existingSeat = _buildSeatedInfoByUserId()[member.userId];
if (existingSeat != null) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$memberName is already seated at $existingSeat'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  return;
}
```

### Bug That Almost Shipped

After the first implementation, the user hot-restarted and reported: "nothing has changed. I can still add already seated club member as many times as I want to as many seat as I want." Screenshot showed Table 2 with 8 seated members, all still enabled in the list.

The diagnosis was exactly the "skip current table" mistake described in Step 3 above. Because all 8 seated members were on the *current* table, my filter skipped them all and the resulting map was empty. Removing the skip fixed it. Lesson: when filtering a stream result for a UI guard, think about the degenerate case where *every* item matches the filter.

---

## Problem 2 — Two Different Waitlists for the Same Cash Game

### Symptom

Player opens the grouped Cash Game 1/2 screen → taps a table card → per-table view opens → taps its "Join Waitlist" button → sees "You're in the waitlist, position 1". Goes back → grouped screen still shows a Join Waitlist FAB → taps it → "You're in the waitlist, position 1" *again* — but now it's a completely separate entry, visible to the admin in the grouped screen's waitlist view.

Two problems conflated:

1. **Duplicate entries**: the per-table button wrote to a per-event waitlist (`clubs/{clubId}/events/{eventId}/waitlist/...`) while the grouped FAB wrote to a stakes-scoped waitlist (`clubs/{clubId}/stakes_waitlists/{stakesKey}/...`). Completely different collections, so neither noticed the other.
2. **Conceptual confusion**: the per-table view shouldn't even have a waitlist button — from the player's perspective, "I want to play 1/2" is a single decision that applies to every table at that stakes, not a per-table decision.

### Fix — Delete the Per-Table Waitlist UI Entirely

The first attempt refactored `member_table_view_screen.dart` to make its Join Waitlist button also use the stakes-waitlist path. The user (correctly) pushed back: "This is getting too complicated. There must be only one waitlist option and that's already working fine in group screen. Players can only see the table and empty / occupied seats, that's it." Removing the UI is the simpler and more correct answer.

Deleted from `member_table_view_screen.dart`:

- Imports: `waitlist_entry.dart`, `waitlist_service.dart`
- State fields: `_userWaitlistEntry`, `_waitlistPosition`, `_totalWaitlistCount`, `_isJoiningWaitlist`, `_isLeavingWaitlist`, `_waitlistSubscription`
- Methods: `_joinWaitlist`, `_leaveWaitlist`, `_useStakesWaitlist`, `_stakesKey`, `_isInWaitlist`
- Widgets: `_buildBottomSection`, `_buildOpenSeatsInfo`, `_buildJoinWaitlistSection`, `_buildWaitlistStatus`

What's left is a clean read-only viewer: teal glow backdrop, back button, table name + occupied/open counts, stakes pill, and the poker table widget with golden seat highlight for "me". No FAB, no bottom action bar, no waitlist state at all. The screen is now ~350 lines instead of ~550.

Added a docstring at the top of the class to document the constraint:

```dart
/// Read-only screen for members to view who's seated at a table.
/// Joining the waitlist is handled exclusively by the grouped cash game
/// screen — there is only one waitlist per stakes and one place to join it.
```

The grouped cash game screen's FAB (which already uses `joinStakesWaitlist`/`leaveStakesWaitlist`) is untouched — it remains the sole entry point.

---

## Problem 3 — Tables Ordered by Event Name, Not Table Number

### Symptom

Grouped Cash Game 1/2 screen shows 4 tables across 2 events:

- Event "Monday Night" → Tables 1, 3
- Event "Late Night" → Tables 2, 4

The grid displayed them in order: Table 2, Table 4, Table 1, Table 3 — because the sort comparator compared event name first ("Late Night" < "Monday Night"), and only fell through to `tableNumber` for tables *within* the same event. User expectation: "Table 1, Table 2, Table 3, Table 4" regardless of which event owns which table.

### Fix

Both sort sites in `grouped_cash_game_screen.dart` (one in `_loadData`, one in the `_navigateToTable` refresh path) had the same structure:

```dart
tables.sort((a, b) {
  final byEvent = a.event.name.compareTo(b.event.name);
  if (byEvent != 0) return byEvent;
  return a.table.tableNumber.compareTo(b.table.tableNumber);
});
```

Simplified both to:

```dart
tables.sort((a, b) => a.table.tableNumber.compareTo(b.table.tableNumber));
```

Since `tableNumber` is an `int`, numeric compare gives correct alphanumeric order (1, 2, 3, …, 10, 11). No ties to worry about — `tableNumber` is unique per club by construction.

Event name is still available on the table card (via `_GroupedTable.event`), so the grouping information isn't lost — it just no longer dictates display order.

---

## Verification

- `flutter analyze` on all four changed files: zero new warnings, only pre-existing `withOpacity` deprecation infos.
- **Double-seating manual test**: admin at Club Dashboard → opens Table 1 → seats Alice at seat 4 → goes back → opens Table 2 → taps Select Member → Alice appears at the bottom of the list, 45% opacity, with subtitle "Table 1 · Seat 4" in mint, trailing `event_seat` icon. Tapping her row is a no-op.
- **Defensive guard test**: temporarily commented out the `enabled: !isSeated` line in the sheet, tapped Alice's row — snackbar appeared: "Alice is already seated at Table 1 · Seat 4". Uncommented.
- **Waitlist test**: player opens grouped Cash Game 1/2 → taps a table card → per-table view has no waitlist UI at all. Back to grouped screen → Join Waitlist FAB still works, shows position 1. Kill & restart → `getUserStakesEntry` restores the in-waitlist state.
- **Sort test**: created 2 live cash events at 1/2, one with tables 1+3 and one with tables 2+4. Grid displayed "Table 1, Table 2, Table 3, Table 4" top-to-bottom, left-to-right. Confirmed.

---

## Lessons / Patterns Worth Remembering

1. **"Skip the current X" filters break in degenerate cases.** When *every* item matches the filter, you end up with an empty result. If the filter is meant to avoid showing redundant info, an empty result is a silent failure. Better: always include everything, then let the UI decide whether to highlight "this is you" versus "this is someone else".
2. **Defensive write-path guards after UI disabling.** UI-level blocking (`enabled: false`) is a UX nicety; a real invariant needs a second check at the service call site. Costs ~6 lines, prevents real-world race conditions from subscription lag.
3. **When a feature is confusing, deleting it beats patching it.** The per-table waitlist was confusing because it duplicated a feature that already existed correctly elsewhere. Refactoring it to share state with the grouped flow would have worked, but removing it entirely made the mental model simpler for both players and future maintainers.
4. **Sort comparators should reflect user intent, not data structure.** The event-then-tableNumber sort made sense from a "data hierarchy" perspective (group by owning event) but not from a user perspective ("which table is Table 1?"). Always ask: what does the user want to read first?
