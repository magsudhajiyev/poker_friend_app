# UI Redesign Batch 3 — Club & Event Screens — March 29, 2026

## Changes Made

### 1. Event Detail Screen (`event_detail_screen.dart`)
- Full redesign from legacy `PokerFriendTheme` to modern design system
- Glassmorphism cards (`#546165` 74%) → solid `#131616` borderRadius 14
- Gradient header with rounded bottom → teal radial gradient + flat header
- RSVP buttons restyled: mint/amber accents, `#131616` cards
- All dialogs restyled: `#131616` bg, borderRadius 18, mint accents
- Compacted all elements to avoid scrolling (reduced spacing, padding, font sizes)
- Attendance preview: replaced pill chips with inline comma-separated names using `LayoutBuilder` + `TextPainter` for "..." overflow
- Required `import 'dart:ui' as ui;` to resolve `TextDirection` conflict with `intl` package

### 2. Event Attendees Screen (`event_attendees_screen.dart`)
- Full redesign to modern design system
- Tab bar: `#131616` bg + mint indicator, compact 38px tabs
- Cards: `#131616`, avatar 48→40, status colors: mint/amber/#FF4444
- Removed "Responded datetime" info from attendee cards

### 3. Club Settings Screen (`club_settings_screen.dart`)
- Tables header: added mint cyan circle `+` button (32x32) aligned right on same line
- Members header: same `+` button wired to `_showInviteMemberDialog()`
- Removed full-width "Add New Table" outline buttons from both empty state and list footer

### 4. Invite Member Dialog (`invite_member_dialog.dart`)
- Full redesign from legacy to modern design system
- Dialog: `#131616` bg, borderRadius 18, added close X button
- Labels: uppercase 12px w600 section headers
- Role selector: mint selected, `white 5%` unselected
- Buttons: Cancel = `white 5%` pill; Send Invite = mint pill with black text

### 5. Live Rankings Screen (`event_rankings_screen.dart`)
- Full redesign with modern design system
- **Fixed timeout bug**: removed backend API call (was hitting local server via `.env`), now reads directly from Firestore via `EventService.getRankingsFromFirestore()`
- **Triton Poker-style layout**:
  - Active players with ordinal ranks (1st, 2nd, 3rd...)
  - Average stack divider line inserted between above-avg and below-avg players
  - BB equivalents shown below stack values (stack / bigBlind)
  - Eliminated players in separate dimmed section below
  - Chip leader highlighted with amber border + trophy icon
- BB fetched from active dealer session via `DealerService.getActiveSessionForTable()`
- Removed table/seat info from eliminated player cards
- Average stack divider: w600 at 45% opacity for readability

## Bug Fix
- **Rankings timeout**: `.env` had `WEBSOCKET_SERVER_URL=http://192.168.100.6:8000` (local server not running). Rankings screen was calling backend API that timed out after ~60s, stacking up with 10s auto-refresh. Fixed by bypassing backend entirely and reading Firestore seat assignments directly.

## Key Patterns
- `intl` package exports `TextDirection` that shadows Flutter's → use `import 'dart:ui' as ui;` and `ui.TextDirection.ltr`
- `LayoutBuilder` + `TextPainter` for measuring text width to fit inline names with "..." overflow
- Rankings: Firestore-only approach is faster and more reliable than backend API for seat-based rankings
