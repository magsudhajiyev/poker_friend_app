# Club Registration and Member Invitation Flow

**Date:** 2026-02-23

## Overview
Implemented a complete club registration system where users can submit club requests to the app admin, who can approve/reject them. Also added member invitation functionality for club admins.

## Features Implemented

### 1. Club Registration Flow
- **New model:** `ClubRequest` with status tracking (pending/approved/rejected)
- **New service:** `ClubRequestService` for managing club registration requests
- **UI:** "Register Club" menu item in navigation drawer
- **Dialog:** `RegisterClubDialog` collecting club name, address, phone, and admin email

### 2. Admin Review Flow
- **Admin section** in Settings screen (visible only to app admins)
- **New screen:** `ClubRequestsScreen` with tabs (All/Pending/Approved/Rejected)
- **Detail dialog:** View full request details, approve or reject with reason
- On approval: Club is created, owner is assigned, email notification sent

### 3. Member Invitation System
- **Invite button** in Club Settings screen (Members section)
- **Dialog:** `InviteMemberDialog` to invite users by email
- **Email notification:** Sends invitation email via Cloud Functions
- **In-app notification:** Creates notification for invited user

### 4. Invitation Response Handling
- **New notification types:** `invitationAccepted`, `invitationDeclined`
- **Tap handler:** When user taps invitation notification, shows Accept/Decline dialog
- **Accept flow:** Notifies club admins, navigates to club dashboard
- **Decline flow:** Removes membership, notifies club admins

## Files Created
- `lib/models/club_request.dart` - ClubRequest model and status enum
- `lib/services/club_request_service.dart` - Service for club registration
- `lib/widgets/register_club_dialog.dart` - Registration form dialog
- `lib/widgets/invite_member_dialog.dart` - Member invitation dialog
- `lib/screens/admin/club_requests_screen.dart` - Admin review screen

## Files Modified
- `lib/models/club_notification.dart` - Added invitation response notification types
- `lib/screens/home_screen.dart` - Added notification tap handling for invitations
- `lib/screens/settings_screen.dart` - Added admin section for club requests
- `lib/screens/club/club_settings_screen.dart` - Added invite button to members section
- `lib/services/club_service.dart` - Added owner info parameters, removeMember()
- `lib/services/club_notification_service.dart` - Added notifyUser() method
- `lib/services/email_service.dart` - Added sendMemberInvitationEmail()
- `lib/services/seat_service.dart` - Added auto-membership on seating
- `lib/widgets/navigation_drawer.dart` - Added "Register Club" menu item

## Key Technical Details

### Club Owner Assignment
When approving a club request, the system looks up the user by `adminEmail`:
- If found: That user becomes the club owner
- If not found: The requester becomes the owner

### Invitation Flow
1. Admin invites user by email
2. User is added as member (role: player)
3. Email + in-app notification sent
4. User taps notification → Accept/Decline dialog
5. Response notifies club admins

### Notification Types
```dart
enum NotificationType {
  // ... existing types ...
  memberInvited,       // When user is invited to join a club
  invitationAccepted,  // When invited user accepts
  invitationDeclined,  // When invited user declines
}
```

## Testing Notes
- Registration flow: Drawer → Register Club → Fill form → Submit
- Admin flow: Settings → Club Requests → Review/Approve/Reject
- Invitation flow: Club Settings → Invite → Enter email → User receives notification
- Response flow: Tap notification → Accept/Decline → Admins notified
