# Tournament Table Break & Session Merging Fixes

**Date:** 2026-04-06
**Status:** Confirmed working after multi-device testing (3 devices: Admin emulator, Dealer phone, Player phone)

---

## Overview

Major batch of fixes addressing tournament table break flow, session merging, live rankings persistence, player session lifecycle, caching, dialog redesigns, and a critical StackOverflow crash.

---

## Bug 1: Live Rankings Showing Stale Players After Table Break

### Problem
After breaking a table during a multi-table tournament, the live rankings continued showing all 17 players (including broken table players) with stale data, or showed "Error loading" when the table was gone.

### Root Cause (Multi-layered)
Rankings were built from three places, all only looking at **active** dealer sessions and seat assignments:
1. `_syncPlayersFromTables()` in `event_dashboard_screen.dart` — event dashboard
2. `getRankingsFromFirestore()` in `event_service.dart` — spectator rankings
3. `_getCurrentRankingsFromTables()` in `event_service.dart` — final standings

When a table breaks and `endSession()` is called, those players vanish from rankings entirely because their dealer session status is `ended` and their seats are cleared.

### Fix (3 parts)

**Part A: `endSession()` always clears seats (dealer_service.dart)**
Previously, event sessions skipped `clearAllSeats()`. Now it always clears seats, because stack carry-over is handled by `getPlayerLastStack()` which reads from the DealerSession document (not seat assignments).

```dart
// Always clear seats when session ends
await SeatService.clearAllSeats(clubId: session.clubId, tableId: session.tableId);
// Only clear table session link for non-event sessions
if (!isEventSession) {
  await TableService.clearTableSession(session.clubId, session.tableId);
}
```

**Part B: New `getAllSessionsForEvent()` method (dealer_service.dart)**
Queries `dealer_sessions` by `eventId` with **no status filter**, returning both active and ended sessions.

**Part C: Merge ended session players into rankings (3 files)**
After the existing per-table loop, all three ranking methods now:
1. Track `real_player_id` for active session players (to distinguish from synthetic `seat_{tableId}_{seat}` IDs)
2. Fetch ALL dealer sessions for the event via `getAllSessionsForEvent()`
3. For each ended session, add players not already present to rankings with their last known stack
4. Show these players with `table_name: '(Reseating)'` label
5. Deduplicate by `playerId` (keep highest stack if same player appears multiple times)

**Key insight:** Ended `DealerSession` documents retain the full `players` map with each player's `playerId`, `displayName`, `stack`, and `seatNumber` — perfect for keeping broken-table players visible.

---

## Bug 2: Duplicate Entry in Stack Growth Chart

### Problem
After a player moves from table 1 to table 2, the Stack Growth chart showed a duplicate data point at the table transition.

### Root Cause
In `mergePlayerEventSessions()`, the `initial` stack history entry from the second session was being converted to `table_change` type, creating a visible point at the same stack value as the last hand from the previous session.

### Fix (dealer_service.dart — mergePlayerEventSessions)
Skip `initial` entries from subsequent sessions entirely:
```dart
if (adjusted['changeType'] == 'initial' && mergedStackHistory.isNotEmpty) {
  continue; // Previous session's last entry already has this stack
}
```

---

## Bug 3: Session Shows Wrong Hand Count (4 Instead of 3)

### Problem
After event completion, session history showed `totalHands: 4` when only 3 hands existed.

### Root Cause
The merged session used `totalHands + totalHandsMerged`, but `totalHands` from dealer sessions already included all hands played in that session. `totalHandsMerged` re-counted the moved hand docs.

### Fix (dealer_service.dart — mergePlayerEventSessions)
Use only `totalHands` (sum of `currentHandNumber` across dealer sessions where the player participated). Removed the unused `totalHandsMerged` variable entirely.

---

## Bug 4: Player Not Kicked from Live Logging After Session Ends

### Problem
When dealer ends a session, the player sees the "Session Ended" dialog but clicking OK doesn't dismiss the screen. The "Exit Table" button also doesn't work.

### Root Cause (2 issues)
1. **Context shadowing:** `builder: (context)` in dialog shadows the State's `context`. After `Navigator.pop(context)` dismisses the dialog, the second pop tries to use the now-disposed dialog context.
2. **Missing session watcher:** Player only detected session end via seat assignment changes, which could miss the event if seats were already cleared.

### Fix (player_session_screen.dart)
1. Renamed dialog builder param to `(dialogContext)`, used `dialogContext` for dialog pop and State's `context` for screen pop:
```dart
builder: (dialogContext) => AlertDialog(
  // ...
  onPressed: () {
    Navigator.pop(dialogContext);  // dismiss dialog
    if (mounted) Navigator.pop(context);  // pop screen using State's context
  },
```
2. Added `_sessionDocSubscription` that watches the dealer session document directly for status changes as backup detection.

---

## Bug 5: Session Not Appearing in History After Event (Cache)

### Problem
After event completion, player had to force-close and reopen the app to see the session in history.

### Root Cause
`mergePlayerEventSessions()` wrote directly to Firestore but never invalidated `AppDataCache`. The session history screen served stale cached data.

### Fix (dealer_service.dart — mergePlayerEventSessions)
Added cache invalidation at the end:
```dart
AppDataCache.markSessionsDirty();
AppDataCache.markHomeDirty();
```

---

## Bug 6: Home Button Not Working from Club Screen

### Problem
Tapping the Home icon in the bottom nav bar while on club screens did nothing.

### Root Cause
Club screens passed `currentScreen: 'home'` to `GlobalBottomNavBar`. The nav bar has an early return guard: `if (currentScreen == screen) return`. Since it thought it was already on 'home', it blocked the tap.

### Fix (club_dashboard_screen.dart, club_settings_screen.dart)
Changed to `GlobalBottomNavBar(currentScreen: 'club')`.

---

## Bug 7: StackOverflow Crash on PlayerSessionScreen

### Problem
After scanning QR code and joining a table, the player sees a red crash screen (StackOverflowError) for a moment before recovery.

### Root Cause
`_formatAmount()` at line 905-906 was infinitely recursive:
```dart
// BEFORE (broken):
String _formatAmount(num amount) =>
    _isTournament ? formatCompactNumber(amount) : _formatAmount(amount);
//                                                  ^^^^^^^^^^^^^ calls itself!
```

### Fix (player_session_screen.dart)
```dart
String _formatAmount(num amount) =>
    _isTournament ? formatCompactNumber(amount) : formatCompactCurrency(amount);
```

---

## Session Merging Architecture (New)

### How it works (EventService.completeEvent → DealerService.mergePlayerEventSessions)

When an admin completes an event:

1. **Collect all unique players** across all dealer sessions for the event
2. **For each player**, call `mergePlayerEventSessions()` which:
   a. Finds ALL `poker_sessions` where the player participated (by `participantIds` + `eventId`/`dealerSessionId`)
   b. Picks the earliest session as **primary**, marks the rest as **secondary**
   c. Moves all `poker_hands` subcollection docs from secondary → primary (with hand number offset for continuous numbering)
   d. Deletes secondary `poker_sessions` documents
   e. Builds merged `stackHistory` from all dealer sessions (skipping duplicate `initial` entries)
   f. Updates primary session with: merged stack history, total hands, all dealer session IDs, analytics fields (buy-in, rebuys, stacks)
   g. Invalidates `AppDataCache`

### Session document now stores:
- `dealerSessionId` — latest dealer session ID (backward compat)
- `dealerSessionIds` — ALL dealer session IDs for the event (new, used by session_hands_screen and session_analytics_screen to fetch hands from all tables)
- `eventId` — links to club event
- `stackHistory` — merged across all tables with continuous hand numbering

### poker_sessions creation flow:
1. **PokerSessionManager** creates initial `poker_sessions` on dealer's device when first hand starts (now stores `dealerSessionId` and `eventId`)
2. **FirebaseService.createSession** stores these IDs if provided
3. **DealerService.createPlayerSessionRecord** checks for existing session by `dealerSessionId` match; updates if found, creates new if not (prevents duplicates)
4. **mergePlayerEventSessions** consolidates everything at event completion

### Session Hands & Analytics screens:
Both `session_hands_screen.dart` and `session_analytics_screen.dart` now check for `dealerSessionIds` (plural) first. If present, they fetch and merge hands from ALL dealer sessions with hand number offsets for continuous numbering.

---

## Auto-Restore Stack on Table Break Reseat

### Problem
When a player from a broken table joins a new table, the dealer had to manually remember and type their chip stack.

### Fix (dealer_table_screen.dart — _showApproveJoinDialog)
For event sessions, the approve dialog now auto-calls `DealerService.getPlayerLastStack()` which:
1. Queries all dealer sessions for the event
2. Finds the player's most recent session (by start time)
3. Returns their last known stack

The chip stack input field is pre-populated with this value.

---

## Dialog Redesigns (Figma-matched, Modern Dark Theme)

All redesigned dialogs now use:
- `Dialog` widget (not `AlertDialog`)
- Background: `#101115`, border: `#1B1E24`
- `GoogleFonts.ibmPlexSans` typography
- Pill-shaped buttons with `BorderRadius.circular(110)`
- Color palette: mint `#89F1EC`, red `#D55A41`, gold `#BD8F2D`

### Dialogs redesigned:
1. **Approve Player** — floating label text field, full-width mint Approve, Cancel (outline) + Reject (red) row
2. **+Player icon removed** — only seat highlight remains for pending joins notification
3. **Busted Player** — centered warning icon in circle, "{name} Busted!" title, red "Remove Player" + outline "Rebuy"
4. **Dealer Handover** — "Dealer Change" title, 3 description paragraphs, gold "Hand Off" button
5. **Resume Session** (dealer_qr_scan_screen.dart) — swap icon, stats rows with dividers, mint "Resume"
6. **Empty Seat / Add Player** — icon chips in dark circles (mint person_add, gold casino), descriptions, divider, Cancel
7. **QR Code** — already modern, no changes needed
8. **Update Blinds** — already modern, no changes needed

---

## Other Improvements

### Hand Details enrichment (dealer_service.dart — getSessionHands)
Now injects `playerNames` and `playerIds` maps from the dealer session document into each hand, so hand review screens can show player names even for dealer-logged hands.

### Hero seat detection (session_hands_screen.dart)
For dealer session hands, if `heroSeatNumber` is null, the code now scans `playerIds` map to find the current user's seat number. Enables proper "Your cards" display in hand review.

### Event detail screen — Return to Seat button
Only shows "Return to my seat" when there's an **active** dealer session at the player's table (not just when seated). Uses new `_checkActiveSession()` method.

### In-memory hand history update (player_session_screen.dart)
After saving hole cards/notes/tags, the in-memory hand history is updated immediately so the hand dropdown shows the data without needing a reload.

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/services/dealer_service.dart` | `endSession()` always clears seats, `getPlayerLastStack()`, `getAllSessionsForEvent()`, `createPlayerSessionRecord()` (was private), `mergePlayerEventSessions()` (new), `getSessionHands()` enrichment, cache invalidation |
| `lib/services/event_service.dart` | Rankings dedup + ended session merge in 3 methods, session merging in `completeEvent()` |
| `lib/services/firebase_service.dart` | `createSession()` accepts `dealerSessionId` and `eventId` |
| `lib/services/seat_service.dart` | Seat claiming now clears stale seats from other tables in same club |
| `lib/models/hand_state_machine.dart` | `PokerSessionManager` stores `dealerSessionId` and `eventId` |
| `lib/screens/club/event_dashboard_screen.dart` | `real_player_id` tracking, ended session merge |
| `lib/screens/club/event_detail_screen.dart` | Fixed `widget.clubId` → `widget.club.id`, active session check for return-to-seat button |
| `lib/screens/club/club_dashboard_screen.dart` | `currentScreen: 'club'` |
| `lib/screens/club/club_settings_screen.dart` | `currentScreen: 'club'` |
| `lib/screens/dealer/dealer_table_screen.dart` | 6 dialog redesigns, +Player icon removed, auto-restore stack, dealerSessionId/eventId linkage |
| `lib/screens/dealer/dealer_qr_scan_screen.dart` | Resume Session dialog redesign |
| `lib/screens/player/player_session_screen.dart` | Context shadowing fix, session doc watcher, `_formatAmount` recursion fix, in-memory hand update |
| `lib/screens/session_analytics_screen.dart` | Multi-table hand fetching via `dealerSessionIds` |
| `lib/screens/session_hands_screen.dart` | Multi-table hand fetching, hero seat detection |

---

## Key Patterns to Remember

1. **Ended DealerSession documents retain full player data** — always available for stack lookups and rankings
2. **`clearAllSeats()` is safe for event sessions** because `getPlayerLastStack()` reads from DealerSession docs, not seat assignments
3. **Cache invalidation is mandatory** after any server-side writes that affect UI data (sessions, home screen)
4. **Dialog context shadowing** — always use `builder: (dialogContext)` and pop with `dialogContext`, then use State's `context` for screen navigation
5. **`dealerSessionIds` (plural) vs `dealerSessionId` (singular)** — plural is for merged multi-table sessions, singular is backward compat
6. **Session merging must happen BEFORE `_endEventDealerSessions()`** in `completeEvent()` — otherwise dealer session data is gone
