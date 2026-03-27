# Critical Dealer Mode Bug Fixes

**Date:** 2026-02-25
**Updated:** Added unified sessions architecture

## Latest Changes: Unified Sessions Collection

### Problem
Two separate collections (`dealer_sessions` and `poker_sessions`) were causing confusion:
- Both were being populated in dealer mode
- Session History showed duplicates

### Solution: `isLive` Flag
Added `isLive` flag to `poker_sessions` to identify dealer/live sessions:

**File:** `lib/services/firebase_service.dart`
- Added `isLive` parameter to `createSession()`
- Added `'isLive': isLive` to session document

**File:** `lib/models/hand_state_machine.dart`
- Added `isLive` field to `PokerSessionManager`
- Constructor now accepts `isLive` parameter
- Passes `isLive` to `FirebaseService.createSession()`

**File:** `lib/screens/dealer/dealer_table_screen.dart`
- Set `isLive: true` when creating `PokerSessionManager`

### Data Flow After Fix
- Dealer sessions: `poker_sessions` with `isLive: true`
- Manual sessions: `poker_sessions` with `isLive: false`
- All hands stored in `poker_sessions/{id}/poker_hands`
- Single source of truth for Session History

---

## Auto-Fill Starting Stack from Event

When club admin defines a starting stack for an event, it now auto-fills when dealer seats players.

**File:** `lib/screens/dealer/dealer_table_screen.dart`

Changed default stack in all player seating dialogs to use `_rebuyStack` (which comes from `event.startingStack`):
- `_showApproveJoinDialog()` - line 1440
- `_seatDealerAsPlayer()` - line 1696
- `_showAddPlayerDialog()` - line 1799
- `_addRandomPlayersForTesting()` - line 3602

```dart
// Before:
final defaultStack = (_dealerSession.bigBlind * 100).toDouble();

// After:
final defaultStack = _rebuyStack > 0 ? _rebuyStack : (_dealerSession.bigBlind * 100.0);
```

`_rebuyStack` is set from `event.startingStack` when event loads (line 233).

---

## Issues Fixed

### Bug 1: Total Invested Shows $33,333 Instead of $33

**Root Cause:**
Code was using `startingStack` (chip count) instead of `buyInAmount` (actual dollars).

**Example:**
- Event: buy-in $33, starting stack 1000 chips
- Bug: Code used 1000 (chips) as buy-in amount
- Result: Total invested = 1000 * (1 + rebuyCount) = huge wrong number

**File:** `lib/services/dealer_service.dart`

**Fix at Line 43:**
```dart
// FROM (WRONG - uses chip count):
final eventBuyIn = activeEvent?.startingStack?.toDouble() ?? 0;

// TO (CORRECT - uses actual buy-in dollars):
final eventBuyIn = activeEvent?.buyInAmount ?? 0;
```

**Fix at Lines 273-274:**
```dart
// FROM (WRONG):
if (event.startingStack != null && event.startingStack! > 0) {
  eventBuyIn = event.startingStack!.toDouble();
}

// TO (CORRECT):
if (event.buyInAmount != null && event.buyInAmount! > 0) {
  eventBuyIn = event.buyInAmount!;
}
```

---

### Bug 2: Auto-Logout When Admin Finishes Event

**Root Cause:**
When admin ended event, `_handleEventEnded()` would navigate away before properly ending the session. The session was ended in `dispose()` which could cause Firebase auth issues.

**File:** `lib/screens/dealer/dealer_table_screen.dart`

**Fix in `_handleEventEnded()`:**
- Made method `async`
- End session BEFORE showing dialog and navigating
- Set `_sessionStarted = false` after ending
- Added `if (!mounted) return` check

**Fix in `dispose()`:**
- Added `_sessionStarted` check to prevent double-ending session
- Only ends session if it wasn't already ended by `_handleEventEnded()`

---

## Files Modified

| File | Change |
|------|--------|
| `lib/services/dealer_service.dart` | Use `buyInAmount` instead of `startingStack` |
| `lib/screens/dealer/dealer_table_screen.dart` | End session before navigation in event end handler |

---

## Verification Steps

### Total Invested Bug
1. Create event: buy-in $33, starting stack 1000 chips
2. Start dealer session, log a few hands
3. End session
4. Session History → should show "Total Invested: $33.00"

### Auto-Logout Bug
1. Dealer starts session (also as player)
2. Admin ends event from admin panel
3. Dealer sees "Event Finished" dialog
4. Click OK → returns to previous screen, NOT login

---

## Related to Previous Fix

This builds on the duplicate sessions fix from earlier:
- `_createPlayerSessionRecord()` calls were already removed
- Duplicate sessions might still appear from OLD test data
- Full app restart recommended for clean testing
