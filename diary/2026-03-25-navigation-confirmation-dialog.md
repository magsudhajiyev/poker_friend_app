# Navigation Confirmation Dialog for Active Sessions

**Date:** 2026-03-25

## Problem

When users were in an active poker session and accidentally navigated away (back button, bottom nav bar), they would lose all their session data without any warning. The session was also being created in Firebase immediately when started, so even empty sessions would appear in Session History.

## Solution

Added a comprehensive navigation confirmation system:

### 1. Confirmation Dialog
When user tries to navigate away from an active session with logged data:
- **Save & Exit** - Saves session and navigates home
- **Discard & Exit** - Deletes session from Firebase/local storage, navigates home
- **Cancel** - Stays on current screen

### 2. PopScope Integration
Wrapped `poker_hand_screen.dart` Scaffold with `PopScope` to intercept:
- Hardware back button (Android)
- UI back arrow button

### 3. Bottom Navigation Interception
Added optional `onNavigationAttempt` callback to `GlobalBottomNavBar`:
- All nav items check callback before navigating
- Callback returns `true` to allow navigation, `false` to block

### 4. Session Deletion
Added `deleteSession()` methods to both services:
- `FirebaseService.deleteSession(sessionId)` - Deletes session and all hands
- `LocalStorageService.deleteSession(sessionId)` - Same for local SQLite

### Key Logic

```dart
bool _hasUnsavedSessionData() {
  if (sessionManager.sessionState != SessionState.active) return false;
  final hasCompletedHands = sessionManager.completedHands.isNotEmpty;
  final hasCurrentHandActions = sessionManager.currentHand?.actions.isNotEmpty ?? false;
  return hasCompletedHands || hasCurrentHandActions;
}
```

- **No data logged** → Delete empty session, navigate without dialog
- **Data logged** → Show confirmation dialog

## Files Modified

- `lib/screens/poker_hand_screen.dart` - PopScope wrapper, dialog, navigation handlers
- `lib/widgets/global_bottom_nav_bar.dart` - Added `onNavigationAttempt` callback
- `lib/services/firebase_service.dart` - Added `deleteSession()` method
- `lib/services/local_storage_service.dart` - Added `deleteSession()` method

## Key Lesson

Sessions are created in Firebase immediately when `startSession()` is called in `hand_state_machine.dart`. This means "discarding" a session requires actually deleting it from Firebase, not just avoiding a save. The session already exists!

## Testing

1. Start a session, don't log any hands, go back → No dialog, session deleted
2. Start a session, log a hand, go back → Dialog appears
3. Test "Save & Exit" → Session saved, appears in history
4. Test "Discard & Exit" → Session deleted, doesn't appear in history
5. Test "Cancel" → Stays on poker hand screen
6. Test bottom nav items → Same dialog behavior
7. Test hardware back button → Same dialog behavior
