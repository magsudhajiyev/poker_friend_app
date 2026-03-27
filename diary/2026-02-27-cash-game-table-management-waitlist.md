# Cash Game Table Management & Waitlist System

**Date**: 2026-02-27

## Overview

Implemented a comprehensive table management and waitlist system for cash game events. This enables club admins to manage multiple tables, seat players, and handle waitlists for live cash game sessions.

## Features Implemented

### 1. Admin Table Management

**Multi-Table View** (`admin_event_tables_screen.dart`):
- Grid view showing all tables assigned to an event
- Real-time seat counts (occupied/open) per table
- Shared waitlist section at bottom
- "+" button to add new tables to running event
- "X" button to close tables (moves players to waitlist)

**Single Table View** (`admin_table_management_screen.dart`):
- Full elliptic table visualization
- Tap seat to see options (seat player, remove, etc.)
- Manual "Notify" button for waitlist (no auto-notify)
- Close table button (only when event has multiple tables)

### 2. Waitlist System

**For Players**:
- Join waitlist via "See Availability" button
- Real-time position tracking
- Notification when seat available (manual trigger by admin)
- "You're Seated" indicator when seated in cash game

**For Admins**:
- View full waitlist with positions
- Manually notify next player in line
- Seat players directly from waitlist
- Players stay in waitlist until actually seated (even after notification)

### 3. Open/Close Table Flow

**Close Table**:
1. Admin clicks close button on table
2. Confirmation dialog shows player count
3. All seated players moved to waitlist (FIFO preserved)
4. Table removed from event's `tableIds`

**Open Table**:
1. Admin clicks "+" button
2. Select from available tables (not in use by other events)
3. Table added to event, seats cleared automatically

### 4. Seat Auto-Population Fix

**Problem**: New events showed players from previous sessions.

**Root Cause**: Seats tied to tables, not events. Old seat data persisted.

**Solution**: Clear seats at multiple points:
- When event is created (tables assigned)
- When table is added to running event
- When event ends (complete or cancel)

### 5. Cash Game Player Experience

**Disabled Features** (tournaments only):
- Live hand logging (PlayerSessionScreen)
- "Return to My Seat" button

**Cash Game Flow**:
- Player sees "See Availability" → joins waitlist
- Admin notifies → player gets push notification
- Admin seats player → button changes to "You're Seated" (unclickable)
- No live logging interface (feature not yet available for cash)

**Admin Flow**:
- Only sees "Manage Tables" button (no "See Availability")

## Files Modified

### Services
- `lib/services/event_service.dart`
  - Added `addTableToEvent()` - add table to running event
  - Added `removeTableFromEvent()` - move players to waitlist, remove table
  - Modified `createEventWithDetails()` - clear seats on assigned tables
  - Modified `completeEvent()` - clear all seats when event ends
  - Modified `cancelEvent()` - clear all seats when event cancelled

- `lib/services/waitlist_service.dart`
  - Added `addPlayerToWaitlist()` - admin can add specific players
  - Modified `getWaitlist()` / `watchWaitlist()` - include 'notified' status

### Screens
- `lib/screens/club/admin_event_tables_screen.dart`
  - Added "+" button for opening new tables
  - Added close button per table card
  - Added state management for available tables
  - Added `_showAddTableDialog()`, `_addTable()`, `_confirmCloseTable()`, `_closeTable()`

- `lib/screens/club/admin_table_management_screen.dart`
  - Removed "Clear All Seats" button
  - Added "Close Table" button (multi-table events only)
  - Added `_confirmCloseTable()`, `_closeTable()` methods

- `lib/screens/club/event_detail_screen.dart`
  - Added `_buildYouAreSeatedIndicator()` for seated cash game players
  - Modified button logic: cash game seated shows "You're Seated"
  - "Return to My Seat" only for tournaments
  - "See Availability" hidden for admins
  - Final Standings only for tournaments

- `lib/screens/club/member_event_tables_screen.dart` (NEW)
  - Multi-table overview for players
  - Shows table availability
  - "Join Waitlist" button if open seats exist

## Key Decisions

1. **Manual Notifications**: Admin must manually notify waitlist players (no auto-notify when seat opens). This gives admins control over seating flow.

2. **Notified Players Stay in Waitlist**: Players with 'notified' status remain visible in waitlist until actually seated. Prevents confusion about who was notified.

3. **Seats Cleared on Event Creation**: Ensures tables start empty even if previous event ended abnormally.

4. **No Live Logging for Cash**: Cash games don't have the live hand logging feature yet. Players just get "You're Seated" status.

## Testing Checklist

- [ ] Create cash game event with Table 1 → seats empty
- [ ] Player joins waitlist → position shown
- [ ] Admin notifies player → player gets notification, stays in waitlist
- [ ] Admin seats player → "You're Seated" indicator shown
- [ ] Player cannot access live logging screen
- [ ] Admin can close table → players moved to waitlist
- [ ] Admin can add new table to running event
- [ ] Complete event → seats cleared
- [ ] Create new event with same table → seats empty

## Related Issues

- Seat data persistence across events (fixed)
- Auto-populate bug from previous sessions (fixed)
- Live logging redirect for cash games (disabled)
