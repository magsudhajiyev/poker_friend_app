# In-App Help & Support System

**Date:** 2026-04-03

## Summary
Added a full in-app support request system for App Store compliance. Users submit support tickets from the navigation drawer, and the app admin manages them in Settings. Push notifications fire in both directions: to admin on new requests, and back to the user on resolve/reject.

---

## Changes Overview

### 1. SupportRequest Model
**New file:** `lib/models/support_request.dart`

- `SupportRequestStatus` enum: `pending`, `resolved`, `rejected`
- Fields: userId, userName, userEmail, category, subject, description, status, submittedAt, reviewedBy, reviewedAt, adminResponse
- `fromFirestore()` and `toFirestore()` serialization

### 2. SupportRequestService
**New file:** `lib/services/support_request_service.dart`

- `submitRequest(category, subject, description)` — creates Firestore doc in `support_requests` collection, notifies all app admins via push
- `getAllRequests({filterStatus})` — fetch all, ordered by submittedAt descending
- `getPendingCount()` — `.count()` query for admin badge
- `resolveRequest(requestId, {response})` — marks resolved, notifies submitting user
- `rejectRequest(requestId, reason)` — marks rejected, notifies submitting user
- `getRequest(requestId)` — fetch single request (used by notification tap handler)
- `isAppAdmin()` — reuses `app_admins` collection (same as ClubRequestService)
- `_notifyAppAdmins()` — iterates `app_admins` docs, sends `ClubNotificationService.notifyUser()` for each

### 3. HelpSupportScreen (User-facing)
**New file:** `lib/screens/help_support_screen.dart`

- Header: back arrow + "Help & Support" title (matches settings_screen pattern)
- GradientBackground
- Category selector: pill chips — Bug Report, Feature Request, Account Issue, Other
- Subject: single-line outline TextField (club_settings_screen pattern)
- Description: multi-line outline TextField (maxLines: 6)
- Submit: PrimaryButton (white, radius 60) with loading spinner
- Validation: both fields required, shows error snackbar
- On success: green snackbar + Navigator.pop

### 4. SupportRequestsScreen (Admin)
**New file:** `lib/screens/admin/support_requests_screen.dart`

- Modern dark theme (GradientBackground, AppColors)
- Tab bar: All, Pending (with red count badge), Closed
- Request cards: category badge (color-coded), status badge, subject, description preview, user name, date
- Inline Resolve/Reject buttons on pending cards
- Tap card → detail dialog with full description + admin response
- Resolve dialog: optional response text field
- Reject dialog: required reason text field
- Pull-to-refresh

### 5. Notification Types Added
**File:** `lib/models/club_notification.dart`

| Type | Direction | Purpose |
|------|-----------|---------|
| `newSupportRequest` | User → Admin | New support ticket submitted |
| `supportRequestUpdated` | Admin → User | Request resolved or rejected |

Both added to `NotificationType` enum with `displayName`, `value`, and `fromString` cases.

### 6. Notification Handling
**Files:** `lib/screens/home_screen.dart`, `lib/screens/notifications_screen.dart`

- `newSupportRequest` tap → navigates to `SupportRequestsScreen`
- `supportRequestUpdated` tap → fetches request from Firestore → shows detail dialog with:
  - Resolved/Rejected icon + title (green/red)
  - Request subject + category
  - Admin response in color-coded container
- Sliding notification overlay `onTap` now routes through `_handleNotificationTap()` (was previously only marking as read)

### 7. Navigation Drawer Update
**File:** `lib/widgets/navigation_drawer.dart`

- "Help & Support" menu item now navigates to `HelpSupportScreen` (was showing a static dialog with old email)
- Removed `_showHelpDialog()` method

### 8. Settings Screen Update
**File:** `lib/screens/settings_screen.dart`

- Added "Support Requests" row in ADMIN section (below Club Requests)
- Added `_pendingSupportCount` state, fetched alongside club request count in `_checkAppAdminStatus()`
- Badge shows pending support count

---

## Firestore Structure

```
support_requests/{requestId}/
  userId: string
  userName: string
  userEmail: string
  category: string        // 'Bug Report', 'Feature Request', 'Account Issue', 'Other'
  subject: string
  description: string
  status: string          // 'pending', 'resolved', 'rejected'
  submittedAt: Timestamp
  reviewedBy?: string     // admin userId
  reviewedAt?: Timestamp
  adminResponse?: string  // resolve response or rejection reason
```

Reuses existing `app_admins/{userId}` collection for admin checks.

---

## Notification Flow

```
User submits support request
  → Firestore write to support_requests/
  → Push notification to ALL app admins: "New Support Request" / "{userName}: [{category}] {subject}"
  → Admin taps notification → SupportRequestsScreen

Admin resolves/rejects request
  → Firestore update (status, adminResponse, reviewedBy, reviewedAt)
  → Push notification to submitting user: "Request Resolved/Update" / "Your request '{subject}' has been resolved/closed."
  → User taps notification → Detail dialog showing admin response
```

---

## Files Summary

| File | Change |
|------|--------|
| `lib/models/support_request.dart` | **New** — SupportRequest model + status enum |
| `lib/services/support_request_service.dart` | **New** — Firestore CRUD + admin notifications |
| `lib/screens/help_support_screen.dart` | **New** — User support form |
| `lib/screens/admin/support_requests_screen.dart` | **New** — Admin management screen |
| `lib/models/club_notification.dart` | Added `newSupportRequest`, `supportRequestUpdated` to enum |
| `lib/screens/home_screen.dart` | Handle new notification types, support response dialog, fix overlay tap routing |
| `lib/screens/notifications_screen.dart` | Handle new notification types, support response dialog |
| `lib/screens/settings_screen.dart` | Added Support Requests admin row with badge |
| `lib/widgets/navigation_drawer.dart` | Help & Support → HelpSupportScreen navigation |

## Key Design Decisions

1. **Firestore-based (no email)**: Support requests stored in Firestore rather than sent via email. Admin sees them in-app with badge counts, same pattern as club requests.
2. **No image_picker/firebase_storage**: Screenshots deferred to keep scope minimal for App Store compliance. Can be added later.
3. **Bidirectional notifications**: Admin notified on submit, user notified on resolve/reject. Both use existing `ClubNotificationService.notifyUser()` which triggers FCM via Cloud Function.
4. **Overlay tap fix**: The sliding notification overlay's `onTap` was only marking as read. Now routes through `_handleNotificationTap()` so ALL notification types are actionable from the overlay.
