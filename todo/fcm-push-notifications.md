# FCM Push Notifications - Production TODO

## Priority: High for production release

## Overview
Currently, the club events system uses in-app notifications stored in Firestore. For production, we need to add Firebase Cloud Messaging (FCM) push notifications so users receive alerts even when the app is closed.

## Requirements

### 1. Package Installation
```yaml
dependencies:
  firebase_messaging: ^latest
```

### 2. Firebase Console Setup
- Enable Cloud Messaging in Firebase Console
- Configure APNs for iOS (requires Apple Developer account)
- Configure Android notification channel

### 3. FCM Token Management
- Store FCM token per user in Firestore (`users/{userId}/fcmTokens`)
- Update token on app launch
- Handle token refresh
- Support multiple devices per user

### 4. Server-Side Notification Sending
- Firebase Admin SDK or Cloud Functions
- Send notifications via FCM when events occur:
  - New event created in club
  - Event starting in 1 hour
  - Event status changed (started/cancelled)
  - Player eliminated from tournament
  - Ranking update

### 5. Client-Side Handling
- Request notification permissions
- Handle foreground notifications (show in-app banner)
- Handle background notifications (system tray)
- Deep linking from notification tap to relevant screen

## Files to Modify

1. `lib/services/club_notification_service.dart`
   - Add `_sendPushNotifications()` implementation
   - Store FCM tokens on login

2. `lib/main.dart`
   - Initialize Firebase Messaging
   - Request permissions
   - Handle background messages

3. `lib/services/auth_service.dart`
   - Store FCM token on sign in
   - Remove FCM token on sign out

## Use Cases

### Event Created
```dart
{
  'title': 'New Event: Friday Night Poker',
  'body': 'Poczekalia has a new event on Jan 25 at 7:00 PM',
  'data': {
    'action': 'view_event',
    'clubId': 'abc123',
    'eventId': 'xyz789'
  }
}
```

### Event Starting Soon
```dart
{
  'title': 'Friday Night Poker starts in 1 hour!',
  'body': 'Get ready for the event at Poczekalia',
  'data': {
    'action': 'view_event',
    'clubId': 'abc123',
    'eventId': 'xyz789'
  }
}
```

### Event Started
```dart
{
  'title': 'Friday Night Poker is now LIVE!',
  'body': 'Join now to spectate at Poczekalia',
  'data': {
    'action': 'spectate_event',
    'clubId': 'abc123',
    'eventId': 'xyz789'
  }
}
```

## Notes
- In-app notifications already work (stored in Firestore)
- FCM is additive - don't remove in-app notifications
- Consider notification preferences per user
- Implement rate limiting to avoid spam
- Test on both iOS and Android

## Related Files
- `lib/services/club_notification_service.dart` (current implementation)
- `lib/models/club_notification.dart`

---
Created: February 2026
Status: TODO for Production
