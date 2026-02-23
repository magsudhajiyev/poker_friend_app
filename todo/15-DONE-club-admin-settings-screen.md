# Club Admin Settings Screen

## Feature Request
Add a settings screen for club admins to manage:
- Table QR codes (view, regenerate, download/print)
- Club settings (default blinds, game type, etc.)
- Member management
- Dealer management

## Current State
- No dedicated settings/admin screen for clubs
- QR codes generated but no easy way to view/manage them
- Settings scattered or not editable

## Required Features

### Table QR Code Management
- View all tables and their QR codes
- Generate QR code images for printing
- Regenerate QR codes if needed
- Download/share QR codes

### Club Settings
- Edit default blinds (SB/BB)
- Edit default game type (cash/tournament)
- Edit default player count
- Toggle BB ante default

### Member Management
- View all members
- Add/remove members
- Set member roles (admin, dealer, player)

### Dealer Management
- View registered dealers
- Invite new dealers
- Remove dealer access

## Files to Create
- `lib/screens/club/club_settings_screen.dart`
- `lib/screens/club/table_qr_management_screen.dart`

## Files to Modify
- `lib/screens/club/club_detail_screen.dart` - add settings button
- `lib/services/club_service.dart` - add settings update methods

## Priority
Medium-High
