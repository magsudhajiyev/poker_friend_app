# Club Registration Flow

## Status: DONE

## Overview
Implemented a complete club registration flow where users can submit registration requests, and the app admin can approve/reject them.

## Features Implemented

### 1. User Registration Flow
- Added "Register Club" button in navigation drawer (after Settings)
- Registration dialog collects: club name, address, phone, admin email
- Success dialog shown after submission

### 2. App Admin Management
- App admins defined in `app_admins` Firestore collection
- Settings screen shows "Club Requests" section for admins
- Pending request count displayed as badge

### 3. Club Requests Management (Admin)
- Full-screen management with tabs: All / Pending / Approved / Rejected
- View request details
- Approve (creates club, sends email notification, sends in-app notification)
- Reject (requires reason, sends in-app notification)

### 4. Smart Owner Assignment
- On approval, looks up user by adminEmail in users collection
- If adminEmail user exists, they become the club owner
- If adminEmail user doesn't exist, requester becomes the owner
- If adminEmail differs from requester, requester is added as admin

### 5. In-App Notifications
- Requester receives notification when club is approved
- Requester receives notification when club is rejected (with reason)
- AdminEmail user receives notification if assigned as owner
- New notification types: clubApproved, clubRejected

### 6. Auto-Membership on Seating
- Players automatically become club members when seated via QR scan
- Players automatically become club members when dealer seats them directly
- Manual/walk-up players (manual_*) are excluded from auto-membership

### 7. Member Invitation System
- Club admins can invite members via email from Club Settings
- Invited users receive email + in-app notification
- Tap notification to see Accept/Decline dialog
- Accept: User navigates to club, admins notified
- Decline: Membership removed, admins notified
- New notification types: memberInvited, invitationAccepted, invitationDeclined

## Files Created
- `lib/models/club_request.dart` - ClubRequest model
- `lib/services/club_request_service.dart` - Request management service
- `lib/widgets/register_club_dialog.dart` - Registration dialog
- `lib/widgets/invite_member_dialog.dart` - Member invitation dialog
- `lib/screens/admin/club_requests_screen.dart` - Admin management screen

## Files Modified
- `lib/widgets/navigation_drawer.dart` - Added "Register Club" menu item
- `lib/screens/settings_screen.dart` - Added app admin section
- `lib/screens/home_screen.dart` - Added invitation notification tap handling
- `lib/screens/club/club_settings_screen.dart` - Added invite member button
- `lib/services/email_service.dart` - Added club approval email, member invitation email
- `lib/services/club_service.dart` - Added ensureMembership(), removeMember(), owner info parameters
- `lib/services/seat_service.dart` - Added auto-membership logic
- `lib/services/club_notification_service.dart` - Added notifyUser() method for single-user notifications
- `lib/models/club_notification.dart` - Added clubApproved, clubRejected, memberInvited, invitationAccepted, invitationDeclined notification types

## Firestore Setup Required
Add document to `app_admins` collection:
```
app_admins/{USER_ID}/
  email: "magsud94@gmail.com"
  displayName: "App Admin"
  addedAt: <timestamp>
```

To find your USER_ID:
1. Sign in to the app
2. Go to Firebase Console > Authentication > Users
3. Copy the UID for magsud94@gmail.com

## Data Structure

### club_requests collection
```
club_requests/{requestId}/
  clubName: String
  address: String
  phone: String
  adminEmail: String
  requestedBy: String (userId)
  requestedByEmail: String
  requestedByName: String
  requestedAt: Timestamp
  status: 'pending' | 'approved' | 'rejected'
  reviewedBy: String? (admin userId)
  reviewedAt: Timestamp?
  rejectionReason: String?
  createdClubId: String? (if approved)
```
