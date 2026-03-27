# UI Updates: Navbar, Notifications, Club Dashboard, and Session History

**Date:** 2026-03-27

## Summary

Implemented multiple UI updates and bug fixes across the application, including navbar improvements, notifications screen functionality restoration, club dashboard redesign, and session history tab bar redesign.

## Changes Made

### 1. Navbar FAB Button Hit Testing Fix

**Problem:** The + (FAB) button in the bottom navigation bar was only clickable at the bottom portion. The center and top parts of the icon did not trigger navigation.

**Root Cause:** The FAB was positioned using `top: -30` to extend above the nav bar bounds. Flutter's Stack `clipBehavior` only affects visual clipping, not hit testing - touch events outside the Stack's bounds are not captured.

**Solution:** Added a center spacer GestureDetector within the Row bounds to capture taps for the visible portion of the FAB:
```dart
// Center spacer for FAB - tappable area for the visible portion
GestureDetector(
  onTap: () => _onFabTap(context),
  behavior: HitTestBehavior.opaque,
  child: const SizedBox(width: 62, height: 51),
),
```

**File:** `lib/widgets/global_bottom_nav_bar.dart`

### 2. Navbar Icons Update

**Changes:**
- Updated navbar icons to use new SVG files with `navbar_` prefix
- Icon paths: `navbar_home.svg`, `navbar_opponents.svg`, `navbar_sessions.svg`, `navbar_profile.svg`
- Fixed color logic: Cyan (#89F1EC) for active, gray (#808285) for inactive

**Note:** The home icon SVG has a default cyan fill, but colorFilter overrides it correctly.

**File:** `lib/widgets/global_bottom_nav_bar.dart`

### 3. Notifications Screen Functionality Restoration

**Problem:** Clicking notifications in the new notifications screen did not trigger proper actions:
- Club dealer invitations didn't open accept/decline modal
- Event notifications didn't navigate to event details

**Root Cause:** The new notifications screen was simply navigating to `InvitationsScreen` for `memberInvited` notifications instead of showing the accept/decline dialog like the old bell icon dropdown.

**Solution:** Ported the full notification handling logic from `home_screen.dart`:

| Method | Purpose |
|--------|---------|
| `_handleMemberInvitationTap()` | Fetches club data and shows dialog |
| `_showInvitationResponseDialog()` | Displays accept/decline UI |
| `_respondToInvitation()` | Handles user's accept/decline choice |
| `_notifyClubAdmins()` | Sends notifications to club admins |
| `_navigateToEventFromNotification()` | Navigates to event detail screen |
| `_navigateToClub()` | Navigates to club dashboard |

**Notification Type Handling:**

| Type | Action |
|------|--------|
| `memberInvited` | Shows accept/decline dialog |
| `eventCreated/Updated/Cancelled/Starting/Started` | Navigates to EventDetailScreen |
| `memberRSVP`, `seatAvailable` | Navigates to EventDetailScreen |
| `clubApproved` | Navigates to ClubDashboardScreen |
| `clubRejected` | Shows snackbar message |
| `invitationAccepted/Declined` | Navigates to ClubDashboardScreen |
| `newClubRequest` | Navigates to ClubRequestsScreen |

**Additional Fix:** Changed checkmark icon color from white to black per Figma design.

**File:** `lib/screens/notifications_screen.dart`

### 4. Club Dashboard Screen Redesign

**Changes:**
- Replaced gradient header with dark background (#02050B)
- Added cyan glow effect using RadialGradient
- Updated header with dark buttons, club name, member count, and settings button
- Removed unused `_buildPillButton` method

**Design Reference:** Figma node 357:3862

**File:** `lib/screens/club/club_dashboard_screen.dart`

### 5. Session History Unified Tab Bar

**Problem:** Initial implementation separated Cash and Tournament tabs into two individual pill buttons. User feedback: "they must be in one unified slot."

**Solution:** Implemented unified tab bar matching Figma design (node 136:1232):

**Design Specs:**
- Outer container: bg `#1B1E24`, border `#35373C`, height 40px, rounded 150px
- Active tab: bg `#02050B`, border `#73D4CF` (cyan), white text
- Inactive tab: no bg/border, gray text `#8C8C8C`

**Animation:** Used `_tabController.animation!.value` for smooth synchronous transitions:
- Tab indicator position follows swipe gesture in real-time
- Text colors lerp smoothly between white and gray during swipe

```dart
// Get animation value (0.0 = Cash, 1.0 = Tournament)
final animValue = _tabController.animation!.value;

// Indicator follows swipe
Positioned(
  left: animValue * tabWidth,
  ...
)

// Text colors lerp
color: Color.lerp(Colors.white, const Color(0xFF8C8C8C), animValue),
```

**File:** `lib/screens/session_history_screen.dart`

## Files Modified

| File | Changes |
|------|---------|
| `lib/widgets/global_bottom_nav_bar.dart` | FAB hit testing fix, navbar icons update |
| `lib/screens/notifications_screen.dart` | Full notification handling, checkmark color fix |
| `lib/screens/club/club_dashboard_screen.dart` | Header redesign with cyan glow |
| `lib/screens/session_history_screen.dart` | Unified tab bar with smooth animations |

## New Imports Added

**notifications_screen.dart:**
- `../services/auth_service.dart`
- `../models/club_member.dart`

**Removed:**
- `invitations_screen.dart` (no longer used)
- `../models/club_event.dart` (unused)

## Design References

| Component | Figma Node |
|-----------|------------|
| Bottom Nav Bar | 370:4719 |
| Notifications Screen | 324:4769 |
| Club Dashboard Header | 357:3862 |
| Session History Tab Bar | 136:1232, 136:1342, 136:1346 |

## Testing Notes

- Verify FAB button is fully clickable (center and top portions)
- Test club invitation notification → should show accept/decline dialog
- Test event notification → should navigate to event detail
- Test session history tab swiping → indicator should follow finger smoothly
- Verify tab text colors animate during swipe

## Related Issues

- Navbar icon colors: The home icon SVG has embedded cyan fill, but colorFilter correctly overrides it for inactive state
- Tab animation: Previous implementation used `_tabController.index` which only updates after swipe completes; now uses `_tabController.animation!` for real-time tracking
