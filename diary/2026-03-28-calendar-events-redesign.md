# 2026-03-28: Calendar Events Redesign & Event Detail Screen

## Changes Made

### Calendar Screen (`lib/screens/calendar_screen.dart`)
- Redesigned event cards to match Figma: `#101115` bg, 16px radius, black border, title row with 3-dot menu, separator, bottom row with date + buy-in
- Added 3-dot tooltip menu (OverlayEntry) with Edit Event and Delete Event options
- Added delete confirmation dialog (bottom sheet matching opponent deletion pattern)
- Added Edit Event drawer (same layout as New Event, pre-filled with existing data)
- Added navigation to new EventDetailScreen for local events (club events still go to club detail)
- Edit from detail screen updates detail screen in-place without popping back to calendar

### Event Detail Screen (`lib/screens/event_detail_screen.dart`) — NEW
- Full event detail view: title, date/time, details card (type, location, buy-in), delete button
- Header with back pill (chevron + month name) and edit pill
- Cyan/green RadialGradient glow at top
- Delete confirmation dialog
- StatefulWidget with mutable state so edits update in-place via callback pattern

### Calendar Header (`lib/design_system/components/headers/calendar_header.dart`)
- Reduced back arrow SVG from 24x24 to 18x15 (matching native viewBox)
- Updated header layout and subtitle styling

### Calendar Picker & Day Cell
- Minor styling adjustments to match Figma

### Seat Setup Screen (`lib/screens/seat_setup_screen.dart`)
- Minor design adjustments

### Poker Hand Screen (`lib/screens/poker_hand_screen.dart`)
- Header redesign: larger title (27px), updated back button color to `#101115`
- Subtitle styling updates

### Winner Selection Dialog (`lib/widgets/winner_selection_dialog.dart`)
- Full redesign to match Figma dark theme
- Added Google Fonts and SVG support

### Notification Service (`lib/services/notification_service.dart`)
- **Bug fix**: Removed `DarwinNotificationAttachment('icons/logo.png')` — iOS requires absolute file URLs for notification attachments, not relative Flutter asset paths. This was causing `PlatformException(Error 100, Invalid attachment file URL)` on every notification schedule.

## Key Patterns
- OverlayEntry for positioned tooltip popups (3-dot menu)
- Stack z-ordering: render header AFTER scroll content for proper tap handling
- Callback pattern for cross-widget state updates (edit from detail screen)
- `onEdit` callback passes `updateDetail` function so parent can update detail screen state without GlobalKey/public state class

## Bug Fixed
- **iOS notification attachment error**: `DarwinNotificationAttachment` requires a file:// URL, not a Flutter asset path. Removed attachment entirely — notifications work fine without custom icon.
