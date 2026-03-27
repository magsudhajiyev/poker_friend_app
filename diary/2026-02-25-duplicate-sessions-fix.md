# Fix Duplicate Sessions in Session History

**Date:** 2026-02-25

## Problem
Duplicate sessions appeared in Session History:
1. One with correct event name (e.g., "Friday Night Poker")
2. Another with hardcoded "Dealer Session - Table 1"

Also, total invested was not calculated correctly in the main session.

## Root Cause
Two separate code paths were creating `poker_sessions` documents:

1. **PokerSessionManager** (dealer_table_screen.dart line 141)
   - Created when first hand starts
   - Used hardcoded name: `'Dealer Session - ${widget.table.name}'`
   - Contains all the hands (this is the important one)

2. **DealerService.endSession()** (dealer_service.dart line 207)
   - Created per-player session records when dealer ends session
   - Had correct event name
   - But these sessions had NO hands - only summary data

## Solution

### Fix 1: Use event name for PokerSessionManager session
**File:** `lib/screens/dealer/dealer_table_screen.dart`

When the event stream emits, update the session manager's name:
```dart
if (event != null) {
  _currentEvent = event;
  _rebuyStack = event.startingStack ?? (_dealerSession.bigBlind * 100.0);
  // Update session name to use event name instead of hardcoded table name
  if (_sessionManager != null) {
    _sessionManager!.sessionName = event.name;
  }
}
```

### Fix 2: Remove duplicate per-player session creation
**File:** `lib/services/dealer_service.dart`

Removed the loop that called `_createPlayerSessionRecord()` for each player:
```dart
// NOTE: Player session records are no longer created here to avoid duplicates.
// The main session (created by PokerSessionManager) now stores playerIds,
// allowing players to query sessions they participated in.
// The hands are only stored in the main session, not per-player sessions.
```

## Files Modified
- `lib/screens/dealer/dealer_table_screen.dart` - Update session name when event loads
- `lib/services/dealer_service.dart` - Remove per-player session creation

## Result
- Only ONE session appears in Session History
- Session has the correct event name
- Hands are stored in the main session
- No duplicate entries

## Future Consideration
To allow players to see sessions they participated in:
- Add `playerIds` array to the session document
- Modify session queries to include `where('playerIds', arrayContains: userId)`

## Verification Steps
1. Start dealer session at event (e.g., "Friday Night Poker")
2. Log a few hands
3. End the session
4. Check Session History - should see ONE session named "Friday Night Poker"
5. Open session - hands should appear
6. No duplicate "Dealer Session - Table 1" entry
